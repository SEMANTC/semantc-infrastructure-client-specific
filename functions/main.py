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
    logger.info("[%s/%s] Running Terraform command: %s", user_id, connector_type, command)
    command_type = command.split()[1] if len(command.split()) > 1 else "execute"
    
    # Adjust timeouts based on command type
    timeouts = {
        "init": 180,  # 3 minutes
        "plan": 300,  # 5 minutes
        "apply": 600  # 10 minutes
    }
    timeout = timeouts.get(command_type, 300)

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
        logger.info("[%s/%s] Starting %s (timeout: %ds)", user_id, connector_type, command_type, timeout)
        start_time = datetime.utcnow()

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
            stdout, stderr = process.communicate(timeout=timeout)
            execution_time = (datetime.utcnow() - start_time).total_seconds()
            logger.info("[%s/%s] %s completed in %.1fs", user_id, connector_type, command_type, execution_time)

            if stdout:
                logger.debug("Terraform stdout:\n%s", stdout)
            if stderr:
                logger.debug("Terraform stderr:\n%s", stderr)

            if process.returncode != 0:
                error_lines = []
                for line in stderr.split('\n'):
                    if any(key in line.lower() for key in ['error:', 'failed:', 'fatal:']):
                        error_msg = line.split(':', 1)[1].strip() if ':' in line else line.strip()
                        if '"@type"' not in error_msg and 'timestamp=' not in error_msg:
                            error_lines.append(error_msg)

                if error_lines:
                    error_message = "\n".join(error_lines)
                    logger.error("[%s/%s] %s failed:\n%s", user_id, connector_type, command_type, error_message)
                    raise Exception(f"{command_type} failed: {error_message}")
                else:
                    error_message = f"Command failed with return code {process.returncode}"
                    logger.error("[%s/%s] %s failed: %s", user_id, connector_type, command_type, error_message)
                    raise Exception(f"{command_type} failed: {error_message}")

            return stdout

        except subprocess.TimeoutExpired:
            process.kill()
            logger.error("[%s/%s] %s timed out after %d seconds", user_id, connector_type, command_type, timeout)
            raise Exception(f"{command_type} timed out after {timeout} seconds")

    except Exception as e:
        if not str(e).startswith(command_type):
            logger.error("[%s/%s] %s error: %s", user_id, connector_type, command_type, str(e))
        raise

def provision_connector(request: Request):
    """HTTP Cloud Function."""
    start_time = datetime.utcnow()
    user_id = None
    connector_type = None
    
    try:
        request_json = request.get_json(silent=True)
        if not request_json or 'userId' not in request_json:
            return ("Missing userId in request", 400)
        
        user_id = request_json['userId']
        connector_type = request_json.get('connectorType', 'xero')
        project_id = os.environ.get('GOOGLE_PROJECT', 'semantc-sandbox')
        
        logger.info("[%s/%s] Starting provisioning", user_id, connector_type)
        
        # Initialize Firestore
        db = firestore.Client()
        connector_ref = db.document(f'users/{user_id}/integrations/connectors')
        doc = connector_ref.get()
        if not doc.exists:
            return (f"No connector configuration found for user {user_id}", 404)
        
        # Update status
        connector_ref.set({
            'provisioningStatus': 'in_progress',
            'lastProvisioningAttempt': start_time
        }, merge=True)
        
        try:
            # Setup and run Terraform
            setup_terraform()
            work_dir = setup_terraform_workspace(user_id)
            
            try:
                # Run Terraform commands with proper error handling
                steps = [
                    ("init", "terraform init -no-color"),
                    ("plan", "terraform plan -no-color -out=tfplan"),
                    ("apply", "terraform apply -no-color -auto-approve tfplan")
                ]
                
                for step_name, cmd in steps:
                    logger.info("[%s/%s] Starting step: %s", user_id, connector_type, step_name)
                    try:
                        run_terraform_command(cmd, work_dir, user_id, connector_type)
                    except Exception as e:
                        total_time = (datetime.utcnow() - start_time).total_seconds()
                        logger.error("[%s/%s] Failed after %.1fs during %s: %s", 
                                   user_id, connector_type, total_time, step_name, str(e))
                        raise Exception(f"Failed during {step_name}: {str(e)}")
                
                total_time = (datetime.utcnow() - start_time).total_seconds()
                logger.info("[%s/%s] Provisioning completed successfully in %.1fs", 
                          user_id, connector_type, total_time)
                
                connector_ref.set({
                    'lastProvisioned': datetime.utcnow(),
                    'provisioningStatus': 'completed',
                    'provisioningDuration': total_time,
                    connector_type: {
                        'resourcesProvisioned': True,
                        'lastProvisioned': datetime.utcnow()
                    }
                }, merge=True)
                
                return ('Resources provisioned successfully', 200)
                
            finally:
                if 'work_dir' in locals():
                    import shutil
                    shutil.rmtree(work_dir, ignore_errors=True)
                    
        except Exception as e:
            error_message = str(e)
            total_time = (datetime.utcnow() - start_time).total_seconds()
            logger.error("[%s/%s] Provisioning failed after %.1fs: %s", 
                        user_id, connector_type, total_time, error_message)
            
            # Update Firestore with error
            connector_ref.set({
                'lastProvisioned': datetime.utcnow(),
                'provisioningStatus': 'failed',
                'provisioningError': error_message,
                'provisioningDuration': total_time
            }, merge=True)
            
            return (f"Failed to provision resources: {error_message}", 500)
            
    except Exception as e:
        total_time = (datetime.utcnow() - start_time).total_seconds()
        logger.error("[%s/%s] Unexpected error after %.1fs: %s", 
                    user_id or 'unknown', connector_type or 'unknown', total_time, str(e))
        return (f"Unexpected error: {str(e)}", 500)