# functions/main.py
import os
import json
import subprocess
import tempfile
import logging
import sys
import glob
from google.cloud import firestore
from google.cloud import storage
from datetime import datetime
from flask import Request

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

def cleanup_service_account(project_id, service_account_email):
    """Clean up service account using gcloud command."""
    try:
        cmd = f"gcloud iam service-accounts delete {service_account_email} --project={project_id} --quiet"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            return True
        else:
            logger.error(f"Error deleting service account: {result.stderr}")
            return False
    except Exception as e:
        logger.error(f"Exception during service account cleanup: {str(e)}")
        return False

def setup_terraform(version="1.5.7"):
    """Install Terraform in the function environment."""
    logger.info(f"=== STARTING TERRAFORM SETUP ===")
    logger.info(f"Setting up Terraform version {version}")
    try:
        # Create directories
        os.makedirs('/tmp/terraform', exist_ok=True)
        logger.info("Created /tmp/terraform directory")
        
        # Download Terraform
        url = f"https://releases.hashicorp.com/terraform/{version}/terraform_{version}_linux_amd64.zip"
        logger.info(f"Downloading Terraform from: {url}")
        subprocess.run(f"curl -o /tmp/terraform/terraform.zip {url}", shell=True, check=True, capture_output=True, text=True)
        
        # Install gcloud CLI if needed for service account management
        subprocess.run("curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-438.0.0-linux-x86_64.tar.gz", 
                      shell=True, check=True, capture_output=True, text=True)
        subprocess.run("tar -xf google-cloud-cli-438.0.0-linux-x86_64.tar.gz", shell=True, check=True)
        subprocess.run("./google-cloud-sdk/install.sh --quiet", shell=True, check=True)
        os.environ['PATH'] = f"{os.getcwd()}/google-cloud-sdk/bin:{os.environ['PATH']}"
        
        # Unzip and make executable
        logger.info("Extracting Terraform binary")
        unzip_result = subprocess.run("unzip -o /tmp/terraform/terraform.zip -d /tmp/terraform", 
                                    shell=True, check=True, capture_output=True, text=True)
        logger.info(f"Unzip output: {unzip_result.stdout}")
        
        subprocess.run("chmod +x /tmp/terraform/terraform", shell=True, check=True)
        logger.info("Made Terraform binary executable")
        
        # Add to PATH
        os.environ['PATH'] = f"/tmp/terraform:{os.environ['PATH']}"
        logger.info(f"Updated PATH: {os.environ['PATH']}")
        
        # Verify installation
        version_output = subprocess.run("terraform version", shell=True, check=True, capture_output=True, text=True)
        logger.info(f"Terraform installation verified: {version_output.stdout}")
        
    except Exception as e:
        logger.error(f"Error setting up Terraform: {str(e)}", exc_info=True)
        raise
    finally:
        logger.info("=== TERRAFORM SETUP COMPLETED ===")

def setup_terraform_workspace(user_id):
    """Download Terraform configs from GCS and set up workspace."""
    logger.info(f"=== SETTING UP TERRAFORM WORKSPACE ===")
    logger.info(f"Setting up workspace for user: {user_id}")
    
    # Create temp directory
    temp_dir = tempfile.mkdtemp()
    logger.info(f"Created temporary directory: {temp_dir}")
    
    try:
        # Initialize Storage client
        storage_client = storage.Client()
        bucket = storage_client.bucket('semantc-terraform-configs')
        
        # List all files in bucket first
        logger.info("Listing files in GCS bucket:")
        blobs = list(bucket.list_blobs())
        for blob in blobs:
            logger.info(f"Found in bucket: {blob.name}")
        
        if not blobs:
            raise Exception("No files found in GCS bucket!")
        
        # Download all terraform files
        for blob in blobs:
            file_path = os.path.join(temp_dir, blob.name)
            os.makedirs(os.path.dirname(file_path), exist_ok=True)
            blob.download_to_filename(file_path)
            logger.info(f"Downloaded: {blob.name} to {file_path}")
        
        # Remove any existing tfvars files
        tfvars_patterns = [
            os.path.join(temp_dir, "**", "*.tfvars"),
            os.path.join(temp_dir, "**", "*.tfvars.json"),
            os.path.join(temp_dir, "**", "*.auto.tfvars"),
            os.path.join(temp_dir, "**", "*.auto.tfvars.json")
        ]
        
        for pattern in tfvars_patterns:
            for tfvars_file in glob.glob(pattern, recursive=True):
                try:
                    os.remove(tfvars_file)
                    logger.info(f"Removed tfvars file: {tfvars_file}")
                except Exception as e:
                    logger.warning(f"Error removing tfvars file {tfvars_file}: {str(e)}")
        
        # Verify workspace contents
        logger.info("Verifying terraform files:")
        for root, dirs, files in os.walk(temp_dir):
            for file in files:
                file_path = os.path.join(root, file)
                logger.info(f"Found file: {file_path}")
        
        return temp_dir
    except Exception as e:
        logger.error(f"Error setting up workspace: {str(e)}", exc_info=True)
        raise
    finally:
        logger.info("=== WORKSPACE SETUP COMPLETED ===")

def run_terraform_command(command, work_dir, user_id, connector_type, project_id="semantc-sandbox", region="us-central1"):
    """Execute terraform command with proper environment and variables."""
    logger.info(f"=== STARTING TERRAFORM COMMAND ===")
    logger.info(f"Command: {command}")
    logger.info(f"Working directory: {work_dir}")
    logger.info(f"Parameters: user_id={user_id}, connector_type={connector_type}, project_id={project_id}, region={region}")

    # Set a timeout for terraform commands (5 minutes)
    TIMEOUT = 300  # seconds

    # Set up environment variables
    env = os.environ.copy()
    env["GOOGLE_PROJECT"] = project_id
    env["TF_VAR_user_id"] = user_id
    env["TF_VAR_project_id"] = project_id
    env["TF_VAR_region"] = region
    env["TF_VAR_connector_type"] = connector_type
    env["TF_LOG"] = "DEBUG"
    env["TF_IN_AUTOMATION"] = "true"
    env["TF_INPUT"] = "false"

    # Only set var-file args for specific commands (not apply with saved plan)
    if "plan" in command:
        env["TF_CLI_ARGS"] = "-no-color"
        env["TF_CLI_ARGS_init"] = "-backend=true -backend-config=\"path=terraform.tfstate\""
        env["TF_CLI_ARGS_plan"] = "-var-file=/dev/null"
    elif "init" in command:
        env["TF_CLI_ARGS"] = "-no-color"
        env["TF_CLI_ARGS_init"] = "-backend=true -backend-config=\"path=terraform.tfstate\""
    else:
        env["TF_CLI_ARGS"] = "-no-color"

    logger.info("Environment variables set:")
    for key in sorted(env.keys()):
        if key.startswith("TF_VAR_") or key.startswith("TF_CLI_") or key == "GOOGLE_PROJECT":
            logger.info(f"{key}={env.get(key)}")

    try:
        # List directory contents
        logger.info(f"Contents of {work_dir} before execution:")
        files_output = subprocess.run(["ls", "-la", work_dir], capture_output=True, text=True, check=True)
        logger.info(files_output.stdout)

        # Start terraform command with timeout
        process = subprocess.Popen(
            command,
            cwd=work_dir,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True,
            text=True
        )

        try:
            stdout, stderr = process.communicate(timeout=TIMEOUT)
            
            if stdout:
                logger.info(f"TERRAFORM STDOUT:\n{stdout}")
            if stderr:
                logger.error(f"TERRAFORM STDERR:\n{stderr}")
            
            if process.returncode != 0:
                error_message = f"Terraform command failed with return code {process.returncode}:\nStdout: {stdout}\nStderr: {stderr}"
                logger.error(error_message)
                raise Exception(error_message)

            return stdout

        except subprocess.TimeoutExpired:
            process.kill()
            logger.error(f"Terraform command timed out after {TIMEOUT} seconds")
            raise Exception(f"Terraform command timed out after {TIMEOUT} seconds")
            
    except Exception as e:
        logger.error(f"Error running terraform command: {str(e)}", exc_info=True)
        raise
    finally:
        logger.info("=== TERRAFORM COMMAND COMPLETED ===")

def provision_connector(request: Request):
    """HTTP Cloud Function."""
    logger.info("\n=== START PROVISION_CONNECTOR FUNCTION ===")
    logger.info(f"Function started at: {datetime.utcnow().isoformat()}")
    
    # Parse the request
    try:
        request_json = request.get_json(silent=True)
        logger.info(f"Request received: {json.dumps(request_json, indent=2)}")
        
        if not request_json or 'userId' not in request_json:
            error_msg = "Missing userId in request"
            logger.error(error_msg)
            return (error_msg, 400)
        
        user_id = request_json['userId']
        connector_type = request_json.get('connectorType', 'xero')  # Default to xero
        force = request_json.get('force', False)  # Add force parameter
        project_id = os.environ.get('GOOGLE_PROJECT', 'semantc-sandbox')
        
        logger.info(f"Processing request for user: {user_id}, connector: {connector_type}, force: {force}")
    except Exception as e:
        error_msg = f"Error parsing request: {str(e)}"
        logger.error(error_msg)
        return (error_msg, 400)
    
    try:
        # Initialize Firestore client
        logger.info("Initializing Firestore client")
        db = firestore.Client()
        
        # Get the connector configuration
        connector_ref = db.document(f'users/{user_id}/integrations/connectors')
        connector_doc = connector_ref.get()
        
        if not connector_doc.exists:
            error_msg = f"No connector document found for user {user_id}"
            logger.warning(error_msg)
            return (error_msg, 404)
                
        # Get connector data
        connector_data = connector_doc.to_dict()
        logger.info(f"Retrieved connector data: {json.dumps(connector_data, indent=2, default=str)}")
        
        try:
            # Update initial status
            status_update = {
                'provisioningStatus': 'in_progress',
                'lastProvisioningAttempt': datetime.utcnow()
            }
            connector_ref.set(status_update, merge=True)
            logger.info("Updated Firestore with in_progress status")
            
            # Setup Terraform and gcloud
            logger.info("Setting up Terraform and gcloud...")
            setup_terraform()
            
            # Handle force cleanup if specified
            if force:
                # Calculate service account email
                sa_email = f"usr-{user_id[:12]}-sa@{project_id}.iam.gserviceaccount.com"
                logger.info(f"Force cleanup requested. Attempting to delete service account: {sa_email}")
                if cleanup_service_account(project_id, sa_email):
                    logger.info("Successfully cleaned up existing service account")
                else:
                    logger.warning("Failed to clean up service account (might not exist)")
            
            # Set up terraform workspace
            logger.info("Setting up Terraform workspace...")
            work_dir = setup_terraform_workspace(user_id)
            logger.info(f"Terraform workspace set up at: {work_dir}")
            
            try:
                # Initialize terraform
                logger.info("Running terraform init...")
                init_output = run_terraform_command(
                    "terraform init -no-color",
                    work_dir,
                    user_id,
                    connector_type
                )
                logger.info("Terraform init completed successfully")
                
                # Import existing resources if they exist and it's not a force operation
                if not force:
                    try:
                        sa_email = f"usr-{user_id[:12]}-sa@{project_id}.iam.gserviceaccount.com"
                        import_cmd = f"terraform import 'module.user_resources.google_service_account.user_sa' 'projects/{project_id}/serviceAccounts/{sa_email}'"
                        logger.info(f"Attempting to import service account with command: {import_cmd}")
                        
                        try:
                            import_output = run_terraform_command(
                                import_cmd,
                                work_dir,
                                user_id,
                                connector_type
                            )
                            logger.info("Successfully imported existing service account")
                        except Exception as e:
                            if "Cannot import non-existent remote object" in str(e):
                                logger.info("Service account doesn't exist yet, continuing with creation")
                            else:
                                logger.warning(f"Import failed (this is ok for new resources): {str(e)}")
                    except Exception as import_error:
                        logger.warning(f"Import attempt failed (this is ok for new resources): {str(import_error)}")
                
                # Run terraform plan
                plan_cmd = "terraform plan -no-color -out=tfplan"
                if force:
                    plan_cmd += " -refresh=false"  # Skip refresh when forcing recreation
                
                logger.info("Running terraform plan...")
                plan_output = run_terraform_command(
                    plan_cmd,
                    work_dir,
                    user_id,
                    connector_type
                )
                logger.info("Terraform plan completed successfully")
                
                # Apply terraform changes
                logger.info("Running terraform apply...")
                apply_output = run_terraform_command(
                    "terraform apply -no-color -auto-approve tfplan",
                    work_dir,
                    user_id,
                    connector_type
                )
                logger.info("Terraform apply completed successfully")
                
                # Update Firestore with success status
                status_update = {
                    'lastProvisioned': datetime.utcnow(),
                    'provisioningStatus': 'completed',
                    connector_type: {
                        'resourcesProvisioned': True,
                        'lastProvisioned': datetime.utcnow()
                    }
                }
                connector_ref.set(status_update, merge=True)
                logger.info("Updated Firestore with success status")
                
                logger.info("=== PROVISION_CONNECTOR FUNCTION COMPLETED SUCCESSFULLY ===")
                return ('Resources provisioned successfully', 200)
                    
            finally:
                # Cleanup temporary directory
                if 'work_dir' in locals():
                    try:
                        import shutil
                        shutil.rmtree(work_dir, ignore_errors=True)
                        logger.info(f"Cleaned up workspace: {work_dir}")
                    except Exception as e:
                        logger.error(f"Error cleaning up workspace: {str(e)}")
                
        except Exception as e:
            error_message = f"Error in terraform execution: {str(e)}"
            logger.error(error_message, exc_info=True)
            
            try:
                if 'connector_ref' in locals():
                    status_update = {
                        'lastProvisioned': datetime.utcnow(),
                        'provisioningStatus': 'failed',
                        'provisioningError': str(e)
                    }
                    connector_ref.set(status_update, merge=True)
                    logger.info("Updated Firestore with error status")
            except Exception as update_error:
                logger.error(f"Error updating status in Firestore: {str(update_error)}")
            
            raise
            
    except Exception as e:
        error_message = f"Error provisioning resources: {str(e)}"
        logger.error(error_message, exc_info=True)
        
        try:
            if 'connector_ref' in locals():
                status_update = {
                    'lastProvisioned': datetime.utcnow(),
                    'provisioningStatus': 'failed',
                    'provisioningError': str(e)
                }
                connector_ref.set(status_update, merge=True)
                logger.info("Updated Firestore with error status")
        except Exception as update_error:
            logger.error(f"Error updating status in Firestore: {str(update_error)}")
        
        return (error_message, 500)