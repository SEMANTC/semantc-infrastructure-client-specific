# modules/connector_resources/main.tf
# CREATE STORAGE BUCKET FOR CONNECTOR DATA
resource "google_storage_bucket" "connector_bucket" {
  name          = "${var.user_id}-${var.connector_type}"
  location      = var.region
  project       = var.project_id
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle {
    prevent_destroy = true
  }
}

# GRANT BUCKET ACCESS
resource "google_storage_bucket_iam_member" "bucket_access" {
  bucket = google_storage_bucket.connector_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.user_service_account}"
}

# CREATE CLOUD RUN INGESTION JOB
resource "google_cloud_run_v2_job" "ingestion_job" {
  name     = "${var.user_id}-${var.connector_type}-ingestion"
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = var.ingestion_image

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
          value = google_storage_bucket.connector_bucket.name
        }
      }

      service_account = var.user_service_account
    }
  }
}

# CREATE CLOUD RUN TRANSFORMATION JOB
resource "google_cloud_run_v2_job" "transformation_job" {
  name     = "${var.user_id}-${var.connector_type}-transformation"
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = var.transformation_image

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
}

# CREATE CLOUD SCHEDULER FOR INGESTION
resource "google_cloud_scheduler_job" "ingestion_scheduler" {
  name             = "${var.user_id}-${var.connector_type}-scheduler"
  description      = "Triggers the ${var.connector_type} ingestion job"
  schedule         = "0 */4 * * *"
  time_zone        = "UTC"
  attempt_deadline = "320s"
  region          = var.region
  project         = var.project_id

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.ingestion_job.name}:run"

    oauth_token {
      service_account_email = var.user_service_account
    }
  }
}