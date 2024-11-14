# infrastructure/terraform/modules/user_resources/main.tf
# USER RESOURCES MODULE - CREATES BASE INFRASTRUCTURE FOR EACH USER
module "names" {
  source  = "../user_id_helper"
  user_id = var.user_id
}

locals {
  # TRY TO GET THE SERVICE ACCOUNT, RETURN NULL IF NOT FOUND
  existing_sa = length(data.google_service_account.existing_sa) > 0 ? data.google_service_account.existing_sa[0].email : null

  # TRY TO GET EXISTING DATASETS, RETURN NULL IF NOT FOUND
  existing_raw_dataset = length(data.google_bigquery_dataset.existing_raw) > 0 ? data.google_bigquery_dataset.existing_raw[0].dataset_id : null

  existing_transformed_dataset = length(data.google_bigquery_dataset.existing_transformed) > 0 ? data.google_bigquery_dataset.existing_transformed[0].dataset_id : null

  # DETERMINE IF RESOURCES SHOULD BE CREATED
  create_sa = local.existing_sa == null
  create_raw_dataset = local.existing_raw_dataset == null
  create_transformed_dataset = local.existing_transformed_dataset == null

  # FINAL SERVICE ACCOUNT EMAIL TO USE
  service_account_email = local.create_sa ? (
    google_service_account.user_sa[0].email
  ) : (
    data.google_service_account.existing_sa[0].email
  )
}

# CHECK IF SERVICE ACCOUNT EXISTS
data "google_service_account" "existing_sa" {
  count = can(data.google_service_account.existing_sa_check[0]) ? 1 : 0
  account_id = module.names.service_account_id
  project    = var.project_id
}

data "google_service_account" "existing_sa_check" {
  count = 0
  account_id = module.names.service_account_id
  project    = var.project_id
}

# CREATE SERVICE ACCOUNT ONLY IF IT DOESN'T EXIST
resource "google_service_account" "user_sa" {
  count        = local.create_sa ? 1 : 0
  account_id   = module.names.service_account_id
  display_name = "service account for user ${var.user_id}"
  project      = var.project_id

  lifecycle {
    prevent_destroy = true
  }
}

# CHECK IF RAW DATASET EXISTS
data "google_bigquery_dataset" "existing_raw" {
  count = can(data.google_bigquery_dataset.existing_raw_check[0]) ? 1 : 0
  dataset_id = module.names.raw_dataset_id
  project    = var.project_id
}

data "google_bigquery_dataset" "existing_raw_check" {
  count = 0
  dataset_id = module.names.raw_dataset_id
  project    = var.project_id
}

# CREATE RAW DATA DATASET ONLY IF IT DOESN'T EXIST
resource "google_bigquery_dataset" "raw_data" {
  count         = local.create_raw_dataset ? 1 : 0
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

# CHECK IF TRANSFORMED DATASET EXISTS
data "google_bigquery_dataset" "existing_transformed" {
  count = can(data.google_bigquery_dataset.existing_transformed_check[0]) ? 1 : 0
  dataset_id = module.names.transformed_dataset_id
  project    = var.project_id
}

data "google_bigquery_dataset" "existing_transformed_check" {
  count = 0
  dataset_id = module.names.transformed_dataset_id
  project    = var.project_id
}

# CREATE TRANSFORMED DATA DATASET ONLY IF IT DOESN'T EXIST
resource "google_bigquery_dataset" "transformed_data" {
  count         = local.create_transformed_dataset ? 1 : 0
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

# GRANT BASIC ROLES TO THE SERVICE ACCOUNT
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