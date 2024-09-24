terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    bucket = "terraform-state-semantic-dev"
    prefix = "terraform/state"
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file(var.terraform_sa_key_path)
}

# Enable Required APIs
resource "google_project_service" "cloud_run" {
  service = "run.googleapis.com"
  project = var.project_id
}

resource "google_project_service" "bigquery" {
  service = "bigquery.googleapis.com"
  project = var.project_id
}

resource "google_project_service" "storage" {
  service = "storage.googleapis.com"
  project = var.project_id
}

resource "google_project_service" "secret_manager" {
  service = "secretmanager.googleapis.com"
  project = var.project_id
}

resource "google_project_service" "cloud_build" {
  service = "cloudbuild.googleapis.com"
  project = var.project_id
}

resource "google_project_service" "cloud_logging" {
  service = "logging.googleapis.com"
  project = var.project_id
}

resource "google_project_service" "cloud_monitoring" {
  service = "monitoring.googleapis.com"
  project = var.project_id
}

# Create Master Service Account
resource "google_service_account" "master_sa" {
  account_id   = "master-sa"
  display_name = "Master Service Account for Pipelines"
  project      = var.project_id
}

# Assign Roles to Master Service Account
resource "google_project_iam_member" "master_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.master_sa.email}"
}

resource "google_project_iam_member" "master_bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.master_sa.email}"
}

resource "google_project_iam_member" "master_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.master_sa.email}"
}

# Modules for Client Resources
module "client_resources" {
  source  = "./modules/client_resources"
  for_each = toset(var.clients)

  client_id     = each.value
  project_id    = var.project_id
  region        = var.region
  data_location = var.data_location
}

# Modules for Cloud Run Jobs using Master Service Account
module "cloud_run_jobs" {
  source = "./modules/cloud_run_jobs"
  for_each = toset(var.clients)

  client_id             = each.value
  project_id            = var.project_id
  region                = var.region
  service_account_email = google_service_account.master_sa.email
  image_ingestion       = "gcr.io/semantc-dev/xero-ingestion:latest"
  image_transformation  = "gcr.io/semantc-dev/xero-transformation:latest"
}