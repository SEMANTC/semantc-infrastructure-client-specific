# infrastructure/terraform/modules/user_resources/main.tf
# USER RESOURCES MODULE - CREATES BASE INFRASTRUCTURE FOR EACH USER
module "names" {
  source  = "../user_id_helper"
  user_id = var.user_id
}

# CREATE SERVICE ACCOUNT
resource "google_service_account" "user_sa" {
  account_id   = module.names.service_account_id
  display_name = "service Account for user ${var.user_id}"
  project      = var.project_id

  lifecycle {
    prevent_destroy = true
  }
}

# CREATE RAW DATA DATASET
resource "google_bigquery_dataset" "raw_data" {
  dataset_id    = module.names.raw_dataset_id
  friendly_name = "raw data for user ${var.user_id}"
  description   = "contains raw data from all connectors for user ${var.user_id}"
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

# CREATE TRANSFORMED DATA DATASET
resource "google_bigquery_dataset" "transformed_data" {
  dataset_id    = module.names.transformed_dataset_id
  friendly_name = "transformed data for user ${var.user_id}"
  description   = "contains transformed data for user ${var.user_id}"
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

# GRANT BASIC ROLES TO THE SERVICE ACCOUNT
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