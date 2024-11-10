# infrastructure/terraform/modules/connector_resources/main.tf
module "user_id" {
  source  = "../user_id_helper"
  user_id = var.user_id
}

locals {
  # create image names based on connector type
  ingestion_image = "gcr.io/${var.project_id}/${lower(var.connector_type)}-ingestion:latest"
  transformation_image = "gcr.io/${var.project_id}/${lower(var.connector_type)}-transformation:latest"
}

# CHECK IF BUCKET EXISTS
data "google_storage_bucket" "existing_bucket" {
  name = "${module.user_id.gcp_name}-${lower(var.connector_type)}"
}

# CREATE STORAGE BUCKET FOR CONNECTOR DATA
resource "google_storage_bucket" "connector_bucket" {
  count         = data.google_storage_bucket.existing_bucket == null ? 1 : 0
  name          = "${module.user_id.gcp_name}-${lower(var.connector_type)}"
  location      = var.region
  project       = var.project_id
  force_destroy = true

  uniform_bucket_level_access = true
}

locals {
  bucket_name = try(
    data.google_storage_bucket.existing_bucket.name,
    google_storage_bucket.connector_bucket[0].name
  )
}

# GRANT BUCKET ACCESS
resource "google_storage_bucket_iam_member" "bucket_access" {
  bucket = local.bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.user_service_account}"
}

# CHECK IF INGESTION JOB EXISTS
data "google_cloud_run_v2_job" "existing_ingestion" {
  name     = "${module.user_id.gcp_name}-${lower(var.connector_type)}-ingestion"
  location = var.region
  project  = var.project_id
}

# CREATE CLOUD RUN INGESTION JOB
resource "google_cloud_run_v2_job" "ingestion_job" {
  count               = data.google_cloud_run_v2_job.existing_ingestion == null ? 1 : 0
  name                = "${module.user_id.gcp_name}-${lower(var.connector_type)}-ingestion"
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
    create_before_destroy = true
  }
}

# CHECK IF TRANSFORMATION JOB EXISTS
data "google_cloud_run_v2_job" "existing_transformation" {
  name     = "${module.user_id.gcp_name}-${lower(var.connector_type)}-transformation"
  location = var.region
  project  = var.project_id
}

# CREATE CLOUD RUN TRANSFORMATION JOB
resource "google_cloud_run_v2_job" "transformation_job" {
  count               = data.google_cloud_run_v2_job.existing_transformation == null ? 1 : 0
  name                = "${module.user_id.gcp_name}-${lower(var.connector_type)}-transformation"
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
    create_before_destroy = true
  }
}

locals {
  ingestion_job_name = try(
    data.google_cloud_run_v2_job.existing_ingestion.name,
    google_cloud_run_v2_job.ingestion_job[0].name
  )
}

# CREATE CLOUD SCHEDULER FOR INGESTION
resource "google_cloud_scheduler_job" "ingestion_scheduler" {
  name             = "${module.user_id.gcp_name}-${lower(var.connector_type)}-scheduler"
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
}