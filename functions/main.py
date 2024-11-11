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

# Configure logging - only show INFO and above
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

def setup_terraform(version="1.5.7"):
    """Install Terraform in the function environment."""
    logger.info("Setting up Terraform v%s", version)
    try:
        os.makedirs('/tmp/terraform', exist_ok=True)
        
        # Download and setup Terraform
        url = f"https://releases.hashicorp.com/terraform/{version}/terraform_{version}_linux_amd64.zip"
        subprocess.run(f"curl -o /tmp/terraform/terraform.zip {url}", shell=True, check=True, capture_output=True, text=True)
        subprocess.run("unzip -o /tmp/terraform/terraform.zip -d /tmp/terraform", shell=True, check=True, capture_output=True, text=True)
        subprocess.run("chmod +x /tmp/terraform/terraform", shell=True, check=True)
        
        # Add to PATH
        os.environ['PATH'] = f"/tmp/terraform:{os.environ['PATH']}"
        
        # Verify installation
        subprocess.run("terraform version", shell=True, check=True, capture_output=True, text=True)
        logger.info("Terraform setup completed successfully")
        
    except Exception as e:
        logger.error("Failed to setup Terraform: %s", str(e))
        raise

def setup_terraform_workspace(user_id):
    """Download Terraform configs from GCS and set up workspace."""
    logger.info("Setting up workspace for user: %s", user_id)
    
    temp_dir = tempfile.mkdtemp()
    
    try:
        # Initialize Storage client and download configs
        storage_client = storage.Client()
        bucket = storage_client.bucket('semantc-terraform-configs')
        
        blobs = list(bucket.list_blobs())
        if not blobs:
            raise Exception("No files found in GCS bucket!")
        
        # Download all terraform files
        for blob in blobs:
            file_path = os.path.join(temp_dir, blob.name)
            os.makedirs(os.path.dirname(file_path), exist_ok=True)
            blob.download_to_filename(file_path)
        
        # Clean up any tfvars files
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
                except Exception:
                    pass
        
        logger.info("Workspace setup completed")
        return temp_dir
        
    except Exception as e:
        logger.error("Failed to setup workspace: %s", str(e))
        raise

def run_terraform_command(command, work_dir, user_id, connector_type, project_id="semantc-sandbox", region="us-central1"):
    """Execute terraform command with proper environment and variables."""
    logger.info("Running Terraform command: %s", command)

    env = os.environ.copy()
    env.update({
        "GOOGLE_PROJECT": project_id,
        "TF_VAR_user_id": user_id,
        "TF_VAR_project_id": project_id,
        "TF_VAR_region": region,
        "TF_VAR_connector_type": connector_type,
        "TF_VAR_master_service_account": "master-sa@semantc-sandbox.iam.gserviceaccount.com",
        "TF_LOG": "ERROR",
        "TF_IN_AUTOMATION": "true",
        "TF_INPUT": "false",
        "TF_CLI_ARGS": "-no-color"
    })

    if "plan" in command or "init" in command:
        env["TF_CLI_ARGS_init"] = "-backend=true -backend-config=\"path=terraform.tfstate\""
        if "plan" in command:
            env["TF_CLI_ARGS_plan"] = "-var-file=/dev/null"

    try:
        process = subprocess.Popen(
            command,
            cwd=work_dir,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True,
            text=True
        )

        stdout, stderr = process.communicate(timeout=300)

        # Log the full output for debugging
        if stdout:
            logger.debug("Terraform stdout:\n%s", stdout)
        if stderr:
            logger.debug("Terraform stderr:\n%s", stderr)

        if process.returncode != 0:
            # Process error messages
            error_lines = []
            for line in stderr.split('\n'):
                if any(key in line.lower() for key in ['error:', 'failed:', 'fatal:']):
                    # Clean up the error message
                    error_msg = line.split(':', 1)[1].strip() if ':' in line else line.strip()
                    # Remove JSON/debugging noise
                    if '"@type"' not in error_msg and 'timestamp=' not in error_msg:
                        error_lines.append(error_msg)

            # Get a clean, meaningful error message
            if error_lines:
                error_message = "\n".join(error_lines)
                logger.error("Terraform command failed:\n%s", error_message)
                raise Exception(f"Terraform execution failed: {error_message}")
            else:
                error_message = f"Command failed with return code {process.returncode}"
                logger.error(error_message)
                raise Exception(error_message)

        return stdout

    except subprocess.TimeoutExpired:
        logger.error("Terraform command timed out after 300 seconds")
        raise Exception("Operation timed out")
    except Exception as e:
        if "execution failed" not in str(e):
            logger.error("Terraform command error: %s", str(e))
        raise

def provision_connector(request: Request):
    """HTTP Cloud Function."""
    try:
        request_json = request.get_json(silent=True)
        if not request_json or 'userId' not in request_json:
            return ("Missing userId in request", 400)
        
        user_id = request_json['userId']
        connector_type = request_json.get('connectorType', 'xero')
        project_id = os.environ.get('GOOGLE_PROJECT', 'semantc-sandbox')
        
        logger.info("Starting provisioning for user %s connector %s", user_id, connector_type)
        
        # Initialize Firestore
        db = firestore.Client()
        connector_ref = db.document(f'users/{user_id}/integrations/connectors')
        doc = connector_ref.get()
        if not doc.exists:
            return (f"No connector configuration found for user {user_id}", 404)
        
        # Update status
        connector_ref.set({
            'provisioningStatus': 'in_progress',
            'lastProvisioningAttempt': datetime.utcnow()
        }, merge=True)
        
        try:
            # Setup and run Terraform
            setup_terraform()
            work_dir = setup_terraform_workspace(user_id)
            
            try:
                # Run Terraform commands with proper error handling
                for cmd in [
                    "terraform init -no-color",
                    "terraform plan -no-color -out=tfplan",
                    "terraform apply -no-color -auto-approve tfplan"
                ]:
                    try:
                        run_terraform_command(cmd, work_dir, user_id, connector_type)
                    except Exception as e:
                        logger.error("Failed during '%s': %s", cmd, str(e))
                        raise Exception(f"Failed during {cmd.split()[1]}: {str(e)}")
                
                connector_ref.set({
                    'lastProvisioned': datetime.utcnow(),
                    'provisioningStatus': 'completed',
                    connector_type: {
                        'resourcesProvisioned': True,
                        'lastProvisioned': datetime.utcnow()
                    }
                }, merge=True)
                
                logger.info("Successfully provisioned resources for user %s", user_id)
                return ('Resources provisioned successfully', 200)
                
            finally:
                if 'work_dir' in locals():
                    import shutil
                    shutil.rmtree(work_dir, ignore_errors=True)
                    
        except Exception as e:
            error_message = str(e)
            logger.error("Provisioning failed for user %s: %s", user_id, error_message)
            
            # Update Firestore with error
            connector_ref.set({
                'lastProvisioned': datetime.utcnow(),
                'provisioningStatus': 'failed',
                'provisioningError': error_message
            }, merge=True)
            
            return (f"Failed to provision resources: {error_message}", 500)
            
    except Exception as e:
        logger.error("Unexpected error during provisioning: %s", str(e))
        return (f"Unexpected error: {str(e)}", 500)