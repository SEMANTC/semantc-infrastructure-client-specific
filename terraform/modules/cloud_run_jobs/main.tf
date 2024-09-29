resource "google_cloud_run_v2_job" "data_ingestion_job" {
  name     = "data-ingestion-${var.new_client_id}"
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = var.image_ingestion

        env {
          name  = "CLIENT_ID"
          value = var.new_client_id
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name = "CLIENT_TOKEN"
          value_source {
            secret_key_ref {
              secret  = "client-${var.new_client_id}-token-xero"
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
  name     = "data-transformation-${var.new_client_id}"
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = var.image_transformation

        env {
          name  = "CLIENT_ID"
          value = var.new_client_id
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name = "CLIENT_TOKEN"
          value_source {
            secret_key_ref {
              secret  = "client-${var.new_client_id}-token-xero"
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