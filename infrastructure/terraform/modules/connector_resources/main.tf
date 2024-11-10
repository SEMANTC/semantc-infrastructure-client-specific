# infrastructure/terraform/modules/connector_resources/main.tf
locals {
  # Ensure consistent lowercase for all resource names
  user_id_lower = lower(var.user_id)
  connector_type_lower = lower(var.connector_type)
  
  bucket_name            = "user-${local.user_id_lower}-${local.connector_type_lower}"
  ingestion_job_name     = "user-${local.user_id_lower}-${local.connector_type_lower}-ingestion"
  transformation_job_name = "user-${local.user_id_lower}-${local.connector_type_lower}-transform"
  scheduler_name         = "user-${local.user_id_lower}-${local.connector_type_lower}-scheduler"
  master_sa             = "master-sa@semantc-sandbox.iam.gserviceaccount.com"
}

# Create connector-specific storage bucket
resource "google_storage_bucket" "connector_bucket" {
  name          = local.bucket_name
  location      = var.region
  project       = var.project_id
  force_destroy = false

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
        image = "gcr.io/${var.project_id}/${local.connector_type_lower}-ingestion:latest"
        
        env {
          name  = "USER_ID"
          value = var.user_id  # Keep original case for env vars
        }
        
        env {
          name  = "CONNECTOR_TYPE"
          value = var.connector_type  # Keep original case for env vars
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
          value = "user_${local.user_id_lower}_raw"
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
        image = "gcr.io/${var.project_id}/${local.connector_type_lower}-transformation:latest"
        
        env {
          name  = "USER_ID"
          value = var.user_id  # Keep original case for env vars
        }
        
        env {
          name  = "CONNECTOR_TYPE"
          value = var.connector_type  # Keep original case for env vars
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "RAW_DATASET"
          value = "user_${local.user_id_lower}_raw"
        }

        env {
          name  = "TRANSFORMED_DATASET"
          value = "user_${local.user_id_lower}_transformed"
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
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      description,
      attempt_deadline
    ]
  }

  depends_on = [google_cloud_run_v2_job.ingestion_job]
}