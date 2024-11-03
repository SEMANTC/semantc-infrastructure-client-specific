# terraform/modules/tenant_resources/main.tf
resource "google_service_account" "tenant_sa" {
  account_id   = "tenant-${substr(var.new_tenant_id, 0, 20)}-sa"  # truncate to ensure <=30 characters
  display_name = "Service account for tenant ${var.new_tenant_id}"
  project      = var.project_id
}

# create Cloud Storage Bucket
resource "google_storage_bucket" "tenant_bucket_xero" {
  name          = "tenant-${var.new_tenant_id}-bucket-xero"
  location      = var.region
  project       = var.project_id
  force_destroy = true

  labels = {
    tenant_id = var.new_tenant_id
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [labels]
  }
}

# create RAW dataset
resource "google_bigquery_dataset" "raw_dataset" {
  dataset_id = "tenant_${replace(var.new_tenant_id, "-", "_")}_raw"  # replace hyphens with underscores
  project    = var.project_id
  location   = var.data_location

  labels = {
    tenant_id = var.new_tenant_id
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [labels]
  }
}

# create TRANSFORMED dataset
resource "google_bigquery_dataset" "transformed_dataset" {
  dataset_id = "tenant_${replace(var.new_tenant_id, "-", "_")}_transformed"  # replace hyphens with underscores
  project    = var.project_id
  location   = var.data_location

  labels = {
    tenant_id = var.new_tenant_id
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [labels]
  }
}

# assign read-only access to tenant Service Account for TRANSFORMED dataset
resource "google_bigquery_dataset_iam_member" "transformed_read_access" {
  dataset_id = google_bigquery_dataset.transformed_dataset.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.tenant_sa.email}"
}

# create Secret in Secret Manager for Tenant token
resource "google_secret_manager_secret" "tenant_token_secret_xero" {
  secret_id = "tenant-${var.new_tenant_id}-token-xero"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

# stores Xero token to Secret
resource "google_secret_manager_secret_version" "tenant_token_version" {
  secret      = google_secret_manager_secret.tenant_token_secret_xero.name
  secret_data = jsonencode({
    access_token  = var.new_tenant_token.access_token
    expires_in    = var.new_tenant_token.expires_in
    expires_at    = var.new_tenant_token.expires_at
    token_type    = var.new_tenant_token.token_type
    refresh_token = var.new_tenant_token.refresh_token
    id_token      = var.new_tenant_token.id_token
    scope         = var.new_tenant_token.scope
  })
}

# grant read-only access to master Service Account
resource "google_secret_manager_secret_iam_member" "master_secret_access" {
  secret_id = google_secret_manager_secret.tenant_token_secret_xero.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.master_sa_email}"
}

# grant permission to add new secret versions to master Service Account
resource "google_secret_manager_secret_iam_member" "master_secret_version_add" {
  secret_id = google_secret_manager_secret.tenant_token_secret_xero.id
  role      = "roles/secretmanager.secretVersionAdder"
  member    = "serviceAccount:${var.master_sa_email}"
}