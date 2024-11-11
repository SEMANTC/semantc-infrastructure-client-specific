# infrastructure/terraform/modules/user_resources/main.tf
locals {
  # Ensure consistent lowercase for user id
  user_id_lower = lower(var.user_id)
  
  # Service account and dataset names
  service_account_id = "usr${lower(substr(local.user_id_lower, 0, 8))}"
  raw_dataset_id     = "user_${local.user_id_lower}_raw"
  transformed_dataset_id = "user_${local.user_id_lower}_transformed"
}

# Read existing service account
data "google_service_account" "existing_sa" {
  count        = 1
  account_id   = local.service_account_id
  project      = var.project_id
}

# Read existing raw dataset
data "google_bigquery_dataset" "raw_data" {
  count      = 1
  dataset_id = local.raw_dataset_id
  project    = var.project_id
}

# Read existing transformed dataset
data "google_bigquery_dataset" "transformed_data" {
  count      = 1
  dataset_id = local.transformed_dataset_id
  project    = var.project_id
}

# Service account resource kept for reference but not created
resource "google_service_account" "user_sa" {
  count        = 0
  account_id   = local.service_account_id
  display_name = "Service Account for user ${var.user_id}"
  project      = var.project_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = all
  }
}

# Raw dataset resource kept for reference but not created
resource "google_bigquery_dataset" "raw_data" {
  count         = 0
  dataset_id    = local.raw_dataset_id
  friendly_name = "Raw data for user ${var.user_id}"
  description   = "Contains raw data from all connectors for user ${var.user_id}"
  location      = "US"
  project       = var.project_id

  access {
    role          = "READER"
    user_by_email = data.google_service_account.existing_sa[0].email
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

# Transformed dataset resource kept for reference but not created
resource "google_bigquery_dataset" "transformed_data" {
  count         = 0
  dataset_id    = local.transformed_dataset_id
  friendly_name = "Transformed data for user ${var.user_id}"
  description   = "Contains transformed data for all connectors for user ${var.user_id}"
  location      = "US"
  project       = var.project_id

  access {
    role          = "READER"
    user_by_email = data.google_service_account.existing_sa[0].email
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

# Grant basic roles to the service account - with lifecycle rules
resource "google_project_iam_member" "bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${data.google_service_account.existing_sa[0].email}"

  lifecycle {
    prevent_destroy = true
    ignore_changes = all
  }
}

resource "google_project_iam_member" "firestore_viewer" {
  project = var.project_id
  role    = "roles/datastore.viewer"
  member  = "serviceAccount:${data.google_service_account.existing_sa[0].email}"

  lifecycle {
    prevent_destroy = true
    ignore_changes = all
  }
}