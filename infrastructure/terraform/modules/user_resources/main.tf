# infrastructure/terraform/modules/user_resources/main.tf
# user resources module - creates base infrastructure for each user
module "names" {
  source  = "../user_id_helper"
  user_id = var.user_id
}

# check if service account already exists
data "google_service_account" "existing_sa" {
  account_id = module.names.service_account_id
  project    = var.project_id
}

# create service account only if it doesn't exist
resource "google_service_account" "user_sa" {
  count        = data.google_service_account.existing_sa == null ? 1 : 0
  account_id   = module.names.service_account_id
  display_name = "service account for user ${var.user_id}"
  project      = var.project_id

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  service_account_email = try(
    google_service_account.user_sa[0].email,
    data.google_service_account.existing_sa.email
  )
}

# check if raw dataset exists
data "google_bigquery_dataset" "existing_raw" {
  dataset_id = module.names.raw_dataset_id
  project    = var.project_id
}

# create raw data dataset only if it doesn't exist
resource "google_bigquery_dataset" "raw_data" {
  count         = data.google_bigquery_dataset.existing_raw == null ? 1 : 0
  dataset_id    = module.names.raw_dataset_id
  friendly_name = "raw data for user ${var.user_id}"
  description   = "contains raw data from all connectors for user ${var.user_id}"
  location      = "US"
  project       = var.project_id

  access {
    role          = "READER"
    user_by_email = local.service_account_email
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

# check if transformed dataset exists
data "google_bigquery_dataset" "existing_transformed" {
  dataset_id = module.names.transformed_dataset_id
  project    = var.project_id
}

# create transformed data dataset only if it doesn't exist
resource "google_bigquery_dataset" "transformed_data" {
  count         = data.google_bigquery_dataset.existing_transformed == null ? 1 : 0
  dataset_id    = module.names.transformed_dataset_id
  friendly_name = "transformed data for user ${var.user_id}"
  description   = "contains transformed data for user ${var.user_id}"
  location      = "US"
  project       = var.project_id

  access {
    role          = "READER"
    user_by_email = local.service_account_email
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

# grant basic roles to the service account
resource "google_project_iam_member" "bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${local.service_account_email}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project_iam_member" "firestore_viewer" {
  project = var.project_id
  role    = "roles/datastore.viewer"
  member  = "serviceAccount:${local.service_account_email}"

  lifecycle {
    prevent_destroy = true
  }
}