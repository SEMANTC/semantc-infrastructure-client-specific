# infrastructure/terraform/modules/user_resources/main.tf
locals {
  service_account_id = "user-${var.user_id}-sa"
  raw_dataset_id     = "user_${var.user_id}_raw"
  transformed_dataset_id = "user_${var.user_id}_transformed"
}

# CREATE SERVICE ACCOUNT
resource "google_service_account" "user_sa" {
  account_id   = local.service_account_id
  display_name = "service account for user ${var.user_id}"
  project      = var.project_id
}

# CREATE RAW DATA DATASET
resource "google_bigquery_dataset" "raw_data" {
  dataset_id    = local.raw_dataset_id
  friendly_name = "raw data for user ${var.user_id}"
  description   = "contains raw data from all connectors for user ${var.user_id}"
  location      = "US"
  project       = var.project_id

  access {
    role          = "READER"
    user_by_email = google_service_account.user_sa.email
  }
}

# CREATE TRANSFORMED DATA DATASET
resource "google_bigquery_dataset" "transformed_data" {
  dataset_id    = local.transformed_dataset_id
  friendly_name = "transformed data for user ${var.user_id}"
  description   = "contains transformed data from all connectors for user ${var.user_id}"
  location      = "US"
  project       = var.project_id

  access {
    role          = "READER"
    user_by_email = google_service_account.user_sa.email
  }
}

# GRANT BASIC ROLES TO THE SERVICE ACCOUNT
resource "google_project_iam_member" "bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${google_service_account.user_sa.email}"
}

resource "google_project_iam_member" "firestore_viewer" {
  project = var.project_id
  role    = "roles/datastore.viewer"
  member  = "serviceAccount:${google_service_account.user_sa.email}"
}