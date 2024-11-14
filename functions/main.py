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

# configure logging with more detail but preserve style
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

def setup_terraform(version="1.5.7"):
    """INSTALL TERRAFORM IN THE FUNCTION ENVIRONMENT"""
    logger.info("setting up terraform v%s", version)
    try:
        os.makedirs('/tmp/terraform', exist_ok=True)
        
        # download and setup terraform with logging
        url = f"https://releases.hashicorp.com/terraform/{version}/terraform_{version}_linux_amd64.zip"
        logger.info("downloading terraform from: %s", url)
        
        download_result = subprocess.run(
            f"curl -o /tmp/terraform/terraform.zip {url}",
            shell=True, capture_output=True, text=True
        )
        if download_result.returncode != 0:
            logger.error("download failed: %s", download_result.stderr)
            raise Exception(f"failed to download terraform: {download_result.stderr}")
            
        unzip_result = subprocess.run(
            "unzip -o /tmp/terraform/terraform.zip -d /tmp/terraform",
            shell=True, capture_output=True, text=True
        )
        if unzip_result.returncode != 0:
            logger.error("unzip failed: %s", unzip_result.stderr)
            raise Exception(f"failed to unzip terraform: {unzip_result.stderr}")
        
        subprocess.run("chmod +x /tmp/terraform/terraform", shell=True, check=True)
        os.environ['PATH'] = f"/tmp/terraform:{os.environ['PATH']}"
        
        # verify with logging
        version_result = subprocess.run(
            "terraform version",
            shell=True, capture_output=True, text=True
        )
        if version_result.returncode == 0:
            logger.info("terraform version: %s", version_result.stdout.strip())
        else:
            logger.error("version check failed: %s", version_result.stderr)
            raise Exception("failed to verify terraform installation")
            
    except Exception as e:
        logger.error("terraform setup failed: %s", str(e))
        raise

def setup_terraform_workspace(user_id):
    """DOWNLOAD TERRAFORM CONFIGS FROM GCS AND SET UP WORKSPACE"""
    logger.info("[%s] setting up workspace", user_id)
    
    temp_dir = tempfile.mkdtemp()
    logger.info("[%s] created temporary directory: %s", user_id, temp_dir)
    
    try:
        storage_client = storage.Client()
        bucket = storage_client.bucket('semantc-terraform-configs')
        
        # list and log all files
        blobs = list(bucket.list_blobs())
        logger.info("[%s] found %d files in gcs bucket", user_id, len(blobs))
        
        for blob in blobs:
            file_path = os.path.join(temp_dir, blob.name)
            os.makedirs(os.path.dirname(file_path), exist_ok=True)
            blob.download_to_filename(file_path)
            logger.info("[%s] downloaded: %s", user_id, blob.name)
        
        # clean up any tfvars files
        tfvars_patterns = [
            os.path.join(temp_dir, "*.tfvars"),
            os.path.join(temp_dir, "*.tfvars.json"),
            os.path.join(temp_dir, "*.auto.tfvars"),
            os.path.join(temp_dir, "*.auto.tfvars.json"),
            # Also check subdirectories
            os.path.join(temp_dir, "**", "*.tfvars"),
            os.path.join(temp_dir, "**", "*.tfvars.json"),
            os.path.join(temp_dir, "**", "*.auto.tfvars"),
            os.path.join(temp_dir, "**", "*.auto.tfvars.json")
        ]
        
        for pattern in tfvars_patterns:
            for tfvars_file in glob.glob(pattern, recursive=True):
                try:
                    os.remove(tfvars_file)
                    logger.info("[%s] removed tfvars file: %s", user_id, tfvars_file)
                except Exception as e:
                    logger.warning("[%s] failed to remove tfvars file %s: %s", user_id, tfvars_file, str(e))
        
        # verify cleanup
        remaining_files = []
        for root, dirs, files in os.walk(temp_dir):
            for file in files:
                rel_path = os.path.relpath(os.path.join(root, file), temp_dir)
                remaining_files.append(rel_path)
        logger.info("[%s] remaining files after cleanup: %s", user_id, json.dumps(remaining_files, indent=2))
        
        return temp_dir
        
    except Exception as e:
        logger.error("[%s] workspace setup failed: %s", user_id, str(e))
        raise

def run_terraform_command(command, work_dir, user_id, connector_type, project_id="semantc-sandbox", region="us-central1"):
    """EXECUTE TERRAFORM COMMAND WITH PROPER ENVIRONMENT AND VARIABLES"""
    logger.info("[%s/%s] running terraform command: %s", user_id, connector_type, command)
    
    # log directory contents before running command
    files = subprocess.run(
        "ls -la", shell=True, cwd=work_dir, capture_output=True, text=True
    )
    logger.info("[%s/%s] directory contents before command:\n%s", user_id, connector_type, files.stdout)
    
    env = os.environ.copy()
    env.update({
        "GOOGLE_PROJECT": project_id,
        "TF_VAR_user_id": user_id,  # ensure this overrides any tfvars
        "TF_VAR_project_id": project_id,
        "TF_VAR_region": region,
        "TF_VAR_connector_type": connector_type,
        "TF_VAR_master_service_account": "master-sa@semantc-sandbox.iam.gserviceaccount.com",
        "TF_LOG": "DEBUG",
        "TF_LOG_PATH": f"/tmp/terraform-{command.split()[1]}.log",
        "TF_IN_AUTOMATION": "true",
        "TF_INPUT": "false",
        "TF_CLI_ARGS": "-no-color"
    })

    if "plan" in command or "init" in command:
        # Force backend to local and prevent tfvars loading
        env["TF_CLI_ARGS_init"] = "-backend=true -backend-config=\"path=terraform.tfstate\""
        if "plan" in command:
            env["TF_CLI_ARGS_plan"] = "-var-file=/dev/null"  # prevent loading of any var files

    # Log environment variables (excluding sensitive values)
    safe_env = {k: v for k, v in env.items() if not any(x in k.lower() for x in ['key', 'secret', 'password', 'token'])}
    logger.info("[%s/%s] environment variables: %s", user_id, connector_type, json.dumps(safe_env, indent=2))

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
        
        stdout, stderr = process.communicate()
        
        # log command output
        if stdout:
            logger.info("[%s/%s] command stdout:\n%s", user_id, connector_type, stdout)
        if stderr:
            logger.warning("[%s/%s] command stderr:\n%s", user_id, connector_type, stderr)
        
        if process.returncode != 0:
            raise Exception(f"command failed with return code {process.returncode}")
            
        return stdout

    except Exception as e:
        logger.error("[%s/%s] command execution failed: %s", user_id, connector_type, str(e))
        raise

def provision_connector(request: Request):
    """HTTP CLOUD FUNCTION"""
    start_time = datetime.utcnow()
    
    try:
        request_json = request.get_json(silent=True)
        if not request_json or 'userId' not in request_json:
            return ("missing userId in request", 400)
        
        user_id = request_json['userId']
        connector_type = request_json.get('connectorType', 'xero')
        project_id = os.environ.get('GOOGLE_PROJECT', 'semantc-sandbox')
        
        logger.info("[%s/%s] starting provisioning", user_id, connector_type)
        
        # initialize firestore
        db = firestore.Client()
        connector_ref = db.document(f'users/{user_id}/integrations/connectors')
        
        try:
            setup_terraform()
            work_dir = setup_terraform_workspace(user_id)
            
            try:
                # run terraform commands with retries
                steps = [
                    ("init", "terraform init"),
                    ("plan", "terraform plan -out=tfplan"),
                    ("apply", "terraform apply -auto-approve tfplan")
                ]
                
                for step_name, cmd in steps:
                    logger.info("[%s/%s] starting step: %s", user_id, connector_type, step_name)
                    run_terraform_command(cmd, work_dir, user_id, connector_type)
                    
                total_time = (datetime.utcnow() - start_time).total_seconds()
                logger.info("[%s/%s] provisioning completed in %.1fs",
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
                
                return ('resources provisioned successfully', 200)
                
            finally:
                if 'work_dir' in locals():
                    import shutil
                    shutil.rmtree(work_dir, ignore_errors=True)
                    
        except Exception as e:
            error_message = str(e)
            total_time = (datetime.utcnow() - start_time).total_seconds()
            logger.error("[%s/%s] provisioning failed after %.1fs: %s",
                        user_id, connector_type, total_time, error_message)
            
            connector_ref.set({
                'lastProvisioned': datetime.utcnow(),
                'provisioningStatus': 'failed',
                'provisioningError': error_message,
                'provisioningDuration': total_time
            }, merge=True)
            
            return (f"failed to provision resources: {error_message}", 500)
            
    except Exception as e:
        logger.error("unexpected error: %s", str(e))
        return (f"unexpected error: {str(e)}", 500)