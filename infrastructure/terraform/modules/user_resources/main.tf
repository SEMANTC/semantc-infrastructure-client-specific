# infrastructure/terraform/modules/user_resources/main.tf
module "user_id" {
  source  = "../user_id_helper"
  user_id = var.user_id
}

locals {
  service_account_id = "${module.user_id.gcp_name}-sa"
  service_account_email = "${local.service_account_id}@${var.project_id}.iam.gserviceaccount.com"
}

# CREATE SERVICE ACCOUNT AND LET GCP HANDLE CONFLICTS IF IT EXISTS
resource "google_service_account" "user_sa" {
  account_id   = local.service_account_id
  display_name = "Service account for user ${var.user_id}"
  project      = var.project_id

  lifecycle {
    ignore_changes = all
    prevent_destroy = true
  }
}

# GRANT BASIC ROLES TO THE SERVICE ACCOUNT
resource "google_project_iam_member" "storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${local.service_account_email}"

  lifecycle {
    prevent_destroy = true
  }
}

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