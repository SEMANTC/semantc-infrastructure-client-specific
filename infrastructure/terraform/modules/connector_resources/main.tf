# infrastructure/terraform/modules/connector_resources/main.tf
module "user_id" {
  source  = "../user_id_helper"
  user_id = var.user_id
}

locals {
  bucket_name = "${module.user_id.gcp_name}-${lower(var.connector_type)}"
  ingestion_image = "gcr.io/${var.project_id}/${lower(var.connector_type)}-ingestion:latest"
  transformation_image = "gcr.io/${var.project_id}/${lower(var.connector_type)}-transformation:latest"
  ingestion_job_name = "${module.user_id.gcp_name}-${lower(var.connector_type)}-ingestion"
  transformation_job_name = "${module.user_id.gcp_name}-${lower(var.connector_type)}-transformation"
  scheduler_name = "${module.user_id.gcp_name}-${lower(var.connector_type)}-scheduler"
}

# TRY TO GET BUCKET
data "google_storage_bucket" "existing_bucket" {
  count = 0  # Skip the data source
  name  = local.bucket_name
}

# CREATE BUCKET
resource "google_storage_bucket" "connector_bucket" {
  name          = local.bucket_name
  location      = var.region
  project       = var.project_id
  force_destroy = true
  uniform_bucket_level_access = true

  lifecycle {
    ignore_changes = all
    prevent_destroy = true
  }
}

# GRANT BUCKET ACCESS
resource "google_storage_bucket_iam_member" "bucket_access" {
  bucket = local.bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.user_service_account}"
}

# TRY TO GET EXISTING INGESTION JOB
data "google_cloud_run_v2_job" "existing_ingestion" {
  count    = 0  # Skip the data source
  name     = local.ingestion_job_name
  location = var.region
  project  = var.project_id
}

# CREATE INGESTION JOB
resource "google_cloud_run_v2_job" "ingestion_job" {
  name                = local.ingestion_job_name
  location            = var.region
  project             = var.project_id
  deletion_protection = false

  template {
    template {
      containers {
        image = local.ingestion_image
        
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
      }

      service_account = var.user_service_account
    }
  }

  lifecycle {
    ignore_changes = all
    prevent_destroy = true
  }
}

# TRY TO GET EXISTING TRANSFORMATION JOB
data "google_cloud_run_v2_job" "existing_transformation" {
  count    = 0  # Skip the data source
  name     = local.transformation_job_name
  location = var.region
  project  = var.project_id
}

# CREATE TRANSFORMATION JOB
resource "google_cloud_run_v2_job" "transformation_job" {
  name                = local.transformation_job_name
  location            = var.region
  project             = var.project_id
  deletion_protection = false

  template {
    template {
      containers {
        image = local.transformation_image
        
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
      }

      service_account = var.user_service_account
    }
  }

  lifecycle {
    ignore_changes = all
    prevent_destroy = true
  }
}

# CREATE CLOUD SCHEDULER
resource "google_cloud_scheduler_job" "ingestion_scheduler" {
  name             = local.scheduler_name
  description      = "Triggers the ${var.connector_type} ingestion job"
  schedule         = "0 */4 * * *"
  time_zone        = "UTC"
  attempt_deadline = "320s"
  region          = var.region
  project         = var.project_id

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${local.ingestion_job_name}:run"

    oauth_token {
      service_account_email = var.user_service_account
    }
  }

  lifecycle {
    ignore_changes = all
    prevent_destroy = true
  }
}