# infrastructure/terraform/modules/user_resources/main.tf
locals {
  # Take first 8 chars of user ID and ensure lowercase
  short_id = lower(substr(var.user_id, 0, 8))
  user_id_lower = lower(var.user_id)
  
  # Format all resource names with lowercase user ID
  service_account_id = "usr${local.short_id}"
  raw_dataset_id     = "user_${local.user_id_lower}_raw"
  transformed_dataset_id = "user_${local.user_id_lower}_transformed"
}

# Create service account - with lifecycle rule
resource "google_service_account" "user_sa" {
  account_id   = local.service_account_id
  display_name = "Service Account for user ${var.user_id}"
  project      = var.project_id

  lifecycle {
    prevent_destroy = true
    ignore_changes = all  # Once created, ignore all changes
  }
}

# Create raw data dataset - with lifecycle rule
resource "google_bigquery_dataset" "raw_data" {
  dataset_id    = local.raw_dataset_id
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
      access,  # Ignore changes to access rules
      labels,
      friendly_name,
      description
    ]
  }
}

# Create transformed data dataset - with lifecycle rule
resource "google_bigquery_dataset" "transformed_data" {
  dataset_id    = local.transformed_dataset_id
  friendly_name = "Transformed data for user ${var.user_id}"
  description   = "Contains transformed data from all connectors for user ${var.user_id}"
  location      = "US"
  project       = var.project_id

  access {
    role          = "READER"
    user_by_email = google_service_account.user_sa.email
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      access,  # Ignore changes to access rules
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
  member  = "serviceAccount:${google_service_account.user_sa.email}"

  lifecycle {
    prevent_destroy = true
    ignore_changes = all
  }
}

resource "google_project_iam_member" "firestore_viewer" {
  project = var.project_id
  role    = "roles/datastore.viewer"
  member  = "serviceAccount:${google_service_account.user_sa.email}"

  lifecycle {
    prevent_destroy = true
    ignore_changes = all
  }
}