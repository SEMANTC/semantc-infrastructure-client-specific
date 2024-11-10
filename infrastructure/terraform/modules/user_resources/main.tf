# infrastructure/terraform/modules/user_resources/main.tf
module "user_id" {
  source  = "../user_id_helper"
  user_id = var.user_id
}

# DATA SOURCE TO CHECK IF SERVICE ACCOUNT EXISTS
data "google_service_account" "existing_sa" {
  account_id = "${module.user_id.gcp_name}-sa"
  project    = var.project_id
}

# CREATE USER SERVICE ACCOUNT ONLY IF IT DOESN'T EXIST
resource "google_service_account" "user_sa" {
  count        = data.google_service_account.existing_sa == null ? 1 : 0
  account_id   = "${module.user_id.gcp_name}-sa"
  display_name = "Service account for user ${var.user_id}"
  project      = var.project_id
}

# USE LOCAL TO HANDLE BOTH EXISTING AND NEW SERVICE ACCOUNTS
locals {
  service_account_email = try(
    data.google_service_account.existing_sa.email,
    google_service_account.user_sa[0].email
  )
}

# GRANT BASIC ROLES TO THE SERVICE ACCOUNT
resource "google_project_iam_member" "storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${local.service_account_email}"
}

resource "google_project_iam_member" "bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.user"
  member  = "serviceAccount:${local.service_account_email}"
}

resource "google_project_iam_member" "firestore_viewer" {
  project = var.project_id
  role    = "roles/datastore.viewer"
  member  = "serviceAccount:${local.service_account_email}"
}