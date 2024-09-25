resource "google_cloud_run_v2_job" "data_ingestion_job" {
  name     = "data-ingestion-${var.client_id}"
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = var.image_ingestion

        env {
          name  = "CLIENT_ID"
          value = var.client_id
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
            name = "CLIENT_TOKEN"
            value_from {
              secret_key_ref {
                name = "client-${var.client_id}-token"
                key  = "latest"  # Adjust if using specific versions
              }
            }
          }
        # Add other environment variables as needed
      }

      service_account = var.service_account_email
    }
  }
}

resource "google_cloud_run_v2_job" "data_transformation_job" {
  name     = "data-transformation-${var.client_id}"
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = var.image_transformation

        env {
          name  = "CLIENT_ID"
          value = var.client_id
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
            name = "CLIENT_TOKEN"
            value_from {
              secret_key_ref {
                name = "client-${var.client_id}-token"
                key  = "latest"  # Adjust if using specific versions
              }
            }
          }

        # Add other environment variables as needed
      }

      service_account = var.service_account_email
    }
  }
}