locals {
  user_id_lower = lower(var.user_id)
  connector_type_lower = lower(var.connector_type)
  
  bucket_name            = "user-${local.user_id_lower}-${local.connector_type_lower}"
  ingestion_job_name     = "user-${local.user_id_lower}-${local.connector_type_lower}-ingestion"
  transformation_job_name = "user-${local.user_id_lower}-${local.connector_type_lower}-transform"
  scheduler_name         = "user-${local.user_id_lower}-${local.connector_type_lower}-scheduler"
  master_sa             = "master-sa@semantc-sandbox.iam.gserviceaccount.com"
}

# Read existing bucket
data "google_storage_bucket" "existing_bucket" {
  count = 1
  name  = local.bucket_name
}

# Read existing ingestion job
data "google_cloud_run_v2_job" "existing_ingestion" {
  count    = 1
  name     = local.ingestion_job_name
  location = var.region
  project  = var.project_id
}

# Read existing transformation job
data "google_cloud_run_v2_job" "existing_transform" {
  count    = 1
  name     = local.transformation_job_name
  location = var.region
  project  = var.project_id
}

# Kept for reference but not created
resource "google_storage_bucket" "connector_bucket" {
  count         = 0
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

# Kept for reference but not created
resource "google_cloud_run_v2_job" "ingestion_job" {
  count    = 0
  name     = local.ingestion_job_name
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = "gcr.io/${var.project_id}/${local.connector_type_lower}-ingestion:latest"
        
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

# Kept for reference but not created
resource "google_cloud_run_v2_job" "transformation_job" {
  count    = 0
  name     = local.transformation_job_name
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = "gcr.io/${var.project_id}/${local.connector_type_lower}-transformation:latest"
        
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

# For scheduler, we'll use import or let it error and handle manually
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
    ignore_changes = all  # Ignore all changes since we can't data source it
  }
}