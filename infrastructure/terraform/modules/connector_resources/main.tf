# Connector Resources Module - Creates connector-specific resources
module "names" {
  source  = "../user_id_helper"
  user_id = var.user_id
}

locals {
  # Clean the connector type to be GCP compliant
  connector_type_clean = lower(replace(var.connector_type, "/[^a-zA-Z0-9]/", ""))
  master_sa          = "master-sa@semantc-sandbox.iam.gserviceaccount.com"
  
  # Standardized resource names
  bucket_name            = "${module.names.storage_prefix}-${local.connector_type_clean}"
  ingestion_job_name     = "${module.names.job_prefix}-${local.connector_type_clean}-ing"
  transformation_job_name = "${module.names.job_prefix}-${local.connector_type_clean}-trn"
  scheduler_name         = "${module.names.scheduler_prefix}-${local.connector_type_clean}"
}

# Create connector-specific storage bucket
resource "google_storage_bucket" "connector_bucket" {
  name          = local.bucket_name
  location      = var.region
  project       = var.project_id
  force_destroy = false  # Prevent accidental deletion

  uniform_bucket_level_access = true

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      labels,
      lifecycle_rule,
      versioning,
      website
    ]
  }
}

# Create ingestion job
resource "google_cloud_run_v2_job" "ingestion_job" {
  name     = local.ingestion_job_name
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = "gcr.io/${var.project_id}/${lower(var.connector_type)}-ingestion:latest"
        
        env {
          name  = "USER_ID"
          value = var.user_id
        }
        
        env {
          name  = "CONNECTOR_TYPE"
          value = var.connector_type
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "BUCKET_NAME"
          value = local.bucket_name
        }

        env {
          name  = "RAW_DATASET"
          value = module.names.raw_dataset_id
        }
      }

      service_account = local.master_sa
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      template[0].template[0].containers[0].resources,
      labels
    ]
  }
}

# Create transformation job
resource "google_cloud_run_v2_job" "transformation_job" {
  name     = local.transformation_job_name
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = "gcr.io/${var.project_id}/${lower(var.connector_type)}-transformation:latest"
        
        env {
          name  = "USER_ID"
          value = var.user_id
        }
        
        env {
          name  = "CONNECTOR_TYPE"
          value = var.connector_type
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "RAW_DATASET"
          value = module.names.raw_dataset_id
        }

        env {
          name  = "TRANSFORMED_DATASET"
          value = module.names.transformed_dataset_id
        }
      }

      service_account = local.master_sa
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      template[0].template[0].containers[0].resources,
      labels
    ]
  }
}

# Create Cloud Scheduler job
resource "google_cloud_scheduler_job" "ingestion_scheduler" {
  name             = local.scheduler_name
  description      = "Triggers the ${var.connector_type} ingestion job for user ${var.user_id}"
  schedule         = "0 */4 * * *"
  time_zone        = "UTC"
  attempt_deadline = "320s"
  region          = var.region
  project         = var.project_id

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${local.ingestion_job_name}:run"

    oauth_token {
      service_account_email = local.master_sa
      scope                = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      description,
      attempt_deadline
    ]
  }
}