resource "google_cloud_run_v2_job" "data_ingestion_job" {
  name     = "data-ingestion-${var.new_tenant_id}"
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = var.image_ingestion

        env {
          name  = "TENANT_ID"
          value = var.new_tenant_id
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name = "TENANT_TOKEN"
          value_source {
            secret_key_ref {
              secret  = "tenant-${var.new_tenant_id}-token-xero"
              version = "latest"
            }
          }
        }
      }

      service_account = var.master_sa_email
    }
  }

  deletion_protection = false

  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
    ]
  }
}

resource "google_cloud_run_v2_job" "data_transformation_job" {
  name     = "data-transformation-${var.new_tenant_id}"
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = var.image_transformation

        env {
          name  = "TENANT_ID"
          value = var.new_tenant_id
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name = "TENANT_TOKEN"
          value_source {
            secret_key_ref {
              secret  = "tenant-${var.new_tenant_id}-token-xero"
              version = "latest"
            }
          }
        }
      }

      service_account = var.master_sa_email
    }
  }

  deletion_protection = false

  lifecycle {
    ignore_changes = [
      template[0].template[0].containers[0].image,
    ]
  }
}

resource "google_cloud_scheduler_job" "data_ingestion_scheduler" {
  name             = "schedule-data-ingestion-${var.new_tenant_id}"
  description      = "Triggers the data ingestion job every 4 hours"
  schedule         = "0 */4 * * *"
  time_zone        = "UTC"
  attempt_deadline = "320s"
  region           = var.region
  project          = var.project_id

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.data_ingestion_job.name}:run"

    oauth_token {
      service_account_email = var.master_sa_email
    }
  }
}

# resource "google_cloud_scheduler_job" "data_transformation_scheduler" {
#   name             = "schedule-data-transformation-${var.new_tenant_id}"
#   description      = "Triggers the data transformation job every 4 hours"
#   schedule         = "0 */4 * * *"
#   time_zone        = "UTC"
#   attempt_deadline = "320s"
#   region           = var.region
#   project          = var.project_id

#   http_target {
#     http_method = "POST"
#     uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.data_transformation_job.name}:run"

#     oauth_token {
#       service_account_email = var.master_sa_email
#     }
#   }
# }