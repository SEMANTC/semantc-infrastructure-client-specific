# infrastructure/terraform/modules/connector_resources/main.tf
locals {
  bucket_name            = "user-${var.user_id}-${lower(var.connector_type)}"
  ingestion_job_name     = "user-${var.user_id}-${lower(var.connector_type)}-ingestion"
  transformation_job_name = "user-${var.user_id}-${lower(var.connector_type)}-transform"
  scheduler_name         = "user-${var.user_id}-${lower(var.connector_type)}-scheduler"
}

# CREATE STORAGE BUCKET FOR CONNECTOR DATA
resource "google_storage_bucket" "connector_bucket" {
  name          = local.bucket_name
  location      = var.region
  project       = var.project_id
  force_destroy = true

  uniform_bucket_level_access = true
}

# CREATE INGESTION JOB
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
          value = "user_${var.user_id}_raw"
        }
      }

      service_account = var.master_service_account
    }
  }
}

# CREATE TRANSFORMATION JOB
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
          value = "user_${var.user_id}_raw"
        }

        env {
          name  = "TRANSFORMED_DATASET"
          value = "user_${var.user_id}_transformed"
        }
      }

      service_account = var.master_service_account
    }
  }
}

# CREATE CLOUD SCHEDULER JOB
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
      service_account_email = var.master_service_account
    }
  }

  depends_on = [google_cloud_run_v2_job.ingestion_job]
}