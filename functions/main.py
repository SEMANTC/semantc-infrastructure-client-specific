import os
import json
import subprocess
import tempfile
import logging
import sys
from google.cloud import firestore
from google.cloud import storage
from datetime import datetime

# Configure logging to show everything
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

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

def run_terraform_command(command, work_dir, user_id, project_id="semantc-sandbox", region="us-central1"):
    """Execute terraform command with proper environment and variables."""
    logger.info(f"Running Terraform command: {command}")
    logger.info(f"Working directory: {work_dir}")
    
    # Set up environment variables
    env = os.environ.copy()
    env["GOOGLE_PROJECT"] = project_id
    env["TF_VAR_user_id"] = user_id
    env["TF_VAR_project_id"] = project_id
    env["TF_VAR_region"] = region
    
    logger.debug(f"Environment variables set: {env}")
    
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

def provision_connector(event, context):
    """Triggered by a change to a Firestore document."""
    # Log the entire event and context
    logger.info("Function triggered!")
    logger.info(f"Event: {json.dumps(event, indent=2)}")
    logger.info(f"Context: {vars(context)}")
    
    try:
        # Extract user ID and path from context
        path_parts = context.resource.split('/documents/')[1].split('/')
        user_id = path_parts[1]
        
        logger.info(f"Starting resource provisioning for user: {user_id}")
        
        # Initialize Firestore client
        db = firestore.Client()
        
        # Get the connector configuration
        connector_ref = db.document(f'users/{user_id}/integrations/connectors')
        connector_doc = connector_ref.get()
        
        if not connector_doc.exists:
            logger.warning(f"No connector document found for user {user_id}")
            return
            
        # Get connector data
        connector_data = connector_doc.to_dict()
        logger.info(f"Retrieved connector data: {json.dumps(connector_data, indent=2)}")
        
        # Verify if there are active connectors
        active_connectors = {k: v for k, v in connector_data.items() 
                           if isinstance(v, dict) and v.get('active', False)}
        
        if not active_connectors:
            logger.warning(f"No active connectors found for user {user_id}")
            return
            
        logger.info(f"Found active connectors: {list(active_connectors.keys())}")
        
        # Set up terraform workspace
        work_dir = setup_terraform_workspace(user_id)
        logger.info(f"Terraform workspace set up at: {work_dir}")
        
        try:
            # Initialize terraform
            init_output = run_terraform_command(
                "terraform init -reconfigure",
                work_dir,
                user_id
            )
            logger.info("Terraform init complete")
            
            # Run terraform plan
            plan_output = run_terraform_command(
                "terraform plan -out=tfplan",
                work_dir,
                user_id
            )
            logger.info("Terraform plan complete")
            
            # Apply terraform changes
            apply_output = run_terraform_command(
                "terraform apply -auto-approve tfplan",
                work_dir,
                user_id
            )
            logger.info("Terraform apply complete")
            
            logger.info(f"Successfully provisioned resources for user {user_id}")
            
            # Update Firestore with provisioning status
            status_update = {
                'lastProvisioned': datetime.utcnow(),
                'provisioningStatus': 'completed'
            }
            connector_ref.set(status_update, merge=True)
            logger.info("Updated Firestore with success status")
            
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
                    'provisioningError': error_message
                }
                connector_ref.set(status_update, merge=True)
                logger.info("Updated Firestore with error status")
        except Exception as update_error:
            logger.error(f"Error updating status in Firestore: {str(update_error)}")
        
        raise