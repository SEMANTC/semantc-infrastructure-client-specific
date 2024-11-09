# modules/user_resources/main.tf
locals {
  # Sanitize names for GCP resources
  sanitized_name = substr(replace(lower(replace(var.user_id, "/[^a-z0-9-]/", "")), "/-+/", "-"), 0, 28)
}

# CREATE USER SERVICE ACCOUNT
resource "google_service_account" "user_sa" {
  account_id   = "${local.sanitized_name}-sa"
  display_name = "Service account for user ${var.user_id}"
  project      = var.project_id
}

# GRANT BASIC ROLES TO THE SERVICE ACCOUNT
resource "google_project_iam_member" "storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.user_sa.email}"
}

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