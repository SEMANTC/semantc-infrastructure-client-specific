resource "google_service_account" "client_sa" {
  account_id   = "client-${var.client_id}-sa"
  display_name = "Service account for client ${var.client_id}"
  project      = var.project_id
}

resource "google_storage_bucket" "client_bucket" {
  name          = "client-${var.client_id}-bucket"
  location      = var.region
  project       = var.project_id
  force_destroy = true

  labels = {
    client_id = var.client_id
  }
}

resource "google_bigquery_dataset" "raw_dataset" {
  dataset_id = "raw_${var.client_id}"
  project    = var.project_id
  location   = var.data_location

  labels = {
    client_id = var.client_id
  }
}

resource "google_bigquery_dataset" "transformed_dataset" {
  dataset_id = "transformed_${var.client_id}"
  project    = var.project_id
  location   = var.data_location

  labels = {
    client_id = var.client_id
  }
}

# Assign Read-Only Access to Client Service Account for Raw Dataset
resource "google_bigquery_dataset_iam_member" "raw_read_access" {
  dataset_id = google_bigquery_dataset.raw_dataset.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.client_sa.email}"
}

# Assign Read-Only Access to Client Service Account for Transformed Dataset
resource "google_bigquery_dataset_iam_member" "transformed_read_access" {
  dataset_id = google_bigquery_dataset.transformed_dataset.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.client_sa.email}"
}

# Assign Read-Only Access to Client Service Account for Storage Bucket
resource "google_storage_bucket_iam_member" "client_bucket_viewer" {
  bucket = google_storage_bucket.client_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.client_sa.email}"
}