import os
import json
import subprocess
import tempfile
import logging
import sys
from google.cloud import firestore
from google.cloud import storage
from datetime import datetime
from flask import Request

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

def setup_terraform(version="1.5.7"):
    """Install Terraform in the function environment."""
    logger.info(f"Setting up Terraform version {version}")
    try:
        # Create directories
        os.makedirs('/tmp/terraform', exist_ok=True)
        
        # Download Terraform
        url = f"https://releases.hashicorp.com/terraform/{version}/terraform_{version}_linux_amd64.zip"
        subprocess.run(f"curl -o /tmp/terraform/terraform.zip {url}", shell=True, check=True)
        
        # Unzip and make executable (with -o flag to force overwrite)
        subprocess.run("unzip -o /tmp/terraform/terraform.zip -d /tmp/terraform", shell=True, check=True)
        subprocess.run("chmod +x /tmp/terraform/terraform", shell=True, check=True)
        
        # Add to PATH
        os.environ['PATH'] = f"/tmp/terraform:{os.environ['PATH']}"
        
        # Verify installation
        subprocess.run("terraform version", shell=True, check=True)
        logger.info("Terraform setup complete")
        
    except Exception as e:
        logger.error(f"Error setting up Terraform: {str(e)}")
        raise

def setup_terraform_workspace(user_id):
    """Download Terraform configs from GCS and set up workspace."""
    logger.info(f"Setting up Terraform workspace for user: {user_id}")
    
    # Create temp directory
    temp_dir = tempfile.mkdtemp()
    logger.info(f"Created temporary directory: {temp_dir}")
    
    try:
        # Initialize Storage client
        storage_client = storage.Client()
        bucket = storage_client.bucket('semantc-terraform-configs')
        
        # Download all terraform files
        blobs = bucket.list_blobs()
        for blob in blobs:
            # Preserve directory structure
            file_path = os.path.join(temp_dir, blob.name)
            os.makedirs(os.path.dirname(file_path), exist_ok=True)
            blob.download_to_filename(file_path)
            logger.info(f"Downloaded: {blob.name} to {file_path}")
        
        return temp_dir
    except Exception as e:
        logger.error(f"Error setting up workspace: {str(e)}", exc_info=True)
        raise

def run_terraform_command(command, work_dir, user_id, connector_type, project_id="semantc-sandbox", region="us-central1"):
    """Execute terraform command with proper environment and variables."""
    logger.info(f"Running Terraform command: {command}")
    logger.info(f"Working directory: {work_dir}")
    
    # Set up environment variables
    env = os.environ.copy()
    env["GOOGLE_PROJECT"] = project_id
    env["TF_VAR_user_id"] = user_id
    env["TF_VAR_project_id"] = project_id
    env["TF_VAR_region"] = region
    env["TF_VAR_connector_type"] = connector_type
    
    logger.debug(f"Environment variables set: {json.dumps({k: env[k] for k in env if 'TF_VAR' in k or 'GOOGLE_PROJECT' in k}, indent=2)}")
    
    try:
        # Run terraform command
        logger.info(f"Executing command in directory: {work_dir}")
        process = subprocess.Popen(
            command,
            cwd=work_dir,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True
        )
        
        stdout, stderr = process.communicate()
        
        if stdout:
            logger.info(f"Terraform stdout: {stdout.decode()}")
        if stderr:
            logger.warning(f"Terraform stderr: {stderr.decode()}")
        
        if process.returncode != 0:
            error_message = f"Terraform command failed: {stderr.decode()}"
            logger.error(error_message)
            raise Exception(error_message)
            
        return stdout.decode()
        
    except Exception as e:
        logger.error(f"Error running terraform command: {str(e)}", exc_info=True)
        raise

def provision_connector(request: Request):
    """HTTP Cloud Function."""
    logger.info("Function provision_connector invoked")
    
    # Setup Terraform first
    setup_terraform()
    
    # Parse the request
    try:
        request_json = request.get_json(silent=True)
        if not request_json or 'userId' not in request_json:
            error_msg = "Missing userId in request"
            logger.error(error_msg)
            return (error_msg, 400)
        
        user_id = request_json['userId']
        # Get specific connector type if provided
        connector_type = request_json.get('connectorType')
        
        logger.info(f"Received request for user: {user_id}, connector: {connector_type}")
    except Exception as e:
        error_msg = f"Error parsing request: {str(e)}"
        logger.error(error_msg)
        return (error_msg, 400)
    
    try:
        # Initialize Firestore client
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
        
        # If no specific connector provided, get the most recently updated one
        if not connector_type:
            active_connectors = {k: v for k, v in connector_data.items() 
                               if isinstance(v, dict) and v.get('active', False)}
            
            if not active_connectors:
                error_msg = f"No active connectors found for user {user_id}"
                logger.warning(error_msg)
                return (error_msg, 404)
            
            # Get most recently updated connector
            connector_type = max(
                active_connectors.items(),
                key=lambda x: x[1].get('updatedAt', datetime.min)
            )[0]
        
        # Verify the specified connector exists and is active
        if (connector_type not in connector_data or 
            not isinstance(connector_data[connector_type], dict) or 
            not connector_data[connector_type].get('active')):
            error_msg = f"Connector {connector_type} not found or not active"
            logger.warning(error_msg)
            return (error_msg, 404)
            
        logger.info(f"Processing connector: {connector_type}")
        
        # Set up terraform workspace
        work_dir = setup_terraform_workspace(user_id)
        logger.info(f"Terraform workspace set up at: {work_dir}")
        
        try:
            # Initialize terraform
            init_output = run_terraform_command(
                "terraform init -reconfigure",
                work_dir,
                user_id,
                connector_type
            )
            logger.info("Terraform init complete")
            
            # Run terraform plan
            plan_output = run_terraform_command(
                "terraform plan -out=tfplan",
                work_dir,
                user_id,
                connector_type
            )
            logger.info("Terraform plan complete")
            
            # Apply terraform changes
            apply_output = run_terraform_command(
                "terraform apply -auto-approve tfplan",
                work_dir,
                user_id,
                connector_type
            )
            logger.info("Terraform apply complete")
            
            logger.info(f"Successfully provisioned resources for user {user_id}")
            
            # Update Firestore with provisioning status
            status_update = {
                'lastProvisioned': datetime.utcnow(),
                'provisioningStatus': 'completed',
                connector_type: {
                    **connector_data[connector_type],
                    'resourcesProvisioned': True,
                    'lastProvisioned': datetime.utcnow()
                }
            }
            connector_ref.set(status_update, merge=True)
            logger.info("Updated Firestore with success status")
            
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