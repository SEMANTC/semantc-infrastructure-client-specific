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

  access {
    role          = "OWNER"
    user_by_email = google_service_account.client_sa.email
  }
}

resource "google_bigquery_dataset" "transformed_dataset" {
  dataset_id = "transformed_${var.client_id}"
  project    = var.project_id
  location   = var.data_location

  labels = {
    client_id = var.client_id
  }

  access {
    role          = "OWNER"
    user_by_email = google_service_account.client_sa.email
  }
}

resource "google_storage_bucket_iam_member" "client_bucket_binding" {
  bucket = google_storage_bucket.client_bucket.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.client_sa.email}"
}

resource "google_project_iam_member" "client_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.client_sa.email}"
}