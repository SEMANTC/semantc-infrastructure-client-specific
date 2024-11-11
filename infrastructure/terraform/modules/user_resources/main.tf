# User Resources Module - Creates base infrastructure for each user
module "names" {
  source  = "../user_id_helper"
  user_id = var.user_id
}

# Create service account
resource "google_service_account" "user_sa" {
  account_id   = module.names.service_account_id
  display_name = "Service Account for user ${var.user_id}"
  project      = var.project_id

  lifecycle {
    prevent_destroy = true
  }
}

# Create raw data dataset
resource "google_bigquery_dataset" "raw_data" {
  dataset_id    = module.names.raw_dataset_id
  friendly_name = "Raw data for user ${var.user_id}"
  description   = "Contains raw data from all connectors for user ${var.user_id}"
  location      = "US"
  project       = var.project_id

  access {
    role          = "READER"
    user_by_email = google_service_account.user_sa.email
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      access,
      labels,
      friendly_name,
      description
    ]
  }
}

# Create transformed data dataset
resource "google_bigquery_dataset" "transformed_data" {
  dataset_id    = module.names.transformed_dataset_id
  friendly_name = "Transformed data for user ${var.user_id}"
  description   = "Contains transformed data for user ${var.user_id}"
  location      = "US"
  project       = var.project_id

  access {
    role          = "READER"
    user_by_email = google_service_account.user_sa.email
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      access,
      labels,
      friendly_name,
      description
    ]
  }
}

# Grant basic roles to the service account
resource "google_project_iam_member" "bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.user_sa.email}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project_iam_member" "firestore_viewer" {
  project = var.project_id
  role    = "roles/datastore.viewer"
  member  = "serviceAccount:${google_service_account.user_sa.email}"

  lifecycle {
    prevent_destroy = true
  }
}