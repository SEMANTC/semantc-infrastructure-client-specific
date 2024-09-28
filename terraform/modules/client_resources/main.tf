# terraform/modules/client_resources/main.tf

resource "google_service_account" "client_sa" {
  account_id   = "client-${substr(var.new_client_id, 0, 20)}-sa"  # truncate to ensure <=30 characters
  display_name = "Service account for client ${var.new_client_id}"
  project      = var.project_id
}

resource "google_storage_bucket" "client_bucket" {
  name          = "client-${var.new_client_id}-bucket"
  location      = var.region
  project       = var.project_id
  force_destroy = true

  labels = {
    client_id = var.new_client_id
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [labels]
  }
}

resource "google_bigquery_dataset" "raw_dataset" {
  dataset_id = "raw_${replace(var.new_client_id, "-", "_")}"  # Replace hyphens with underscores
  project    = var.project_id
  location   = var.data_location

  labels = {
    client_id = var.new_client_id
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [labels]
  }
}

resource "google_bigquery_dataset" "transformed_dataset" {
  dataset_id = "transformed_${replace(var.new_client_id, "-", "_")}"  # replace hyphens with underscores
  project    = var.project_id
  location   = var.data_location

  labels = {
    client_id = var.new_client_id
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [labels]
  }
}

# Assign read-only access to client Service Account for TRANSFORMED dataset
resource "google_bigquery_dataset_iam_member" "transformed_read_access" {
  dataset_id = google_bigquery_dataset.transformed_dataset.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.client_sa.email}"
}

# Create Secret in Secret Manager for Client Token
resource "google_secret_manager_secret" "client_token_secret" {
  secret_id = "client-${var.new_client_id}-token"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_secret_manager_secret_version" "client_token_version" {
  secret      = google_secret_manager_secret.client_token_secret.name
  secret_data = var.new_client_token
}

# grant access to Master Service Account to Access Secrets
resource "google_secret_manager_secret_iam_member" "master_secret_access" {
  secret_id = google_secret_manager_secret.client_token_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.master_sa_email}"
}