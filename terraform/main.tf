terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "terraform-state-semantic-dev"
    prefix = "terraform/client_state"
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file(var.terraform_sa_key_path)
}

# modules for client resources
module "client_resources" {
  source            = "./modules/client_resources"
  for_each          = toset(var.clients)

  client_id         = each.value
  project_id        = var.project_id
  region            = var.region
  data_location     = var.data_location
  client_token      = var.client_tokens[each.value]
  master_sa_email   = var.master_sa_email
}

# modules for cloud run jobs using master service account
module "cloud_run_jobs" {
  source = "./modules/cloud_run_jobs"
  for_each = toset(var.clients)

  client_id             = each.value
  project_id            = var.project_id
  region                = var.region
  service_account_email = var.master_sa_email
  image_ingestion       = "gcr.io/semantc-dev/xero-ingestion:latest"
  image_transformation  = "gcr.io/semantc-dev/xero-ingestion:latest" # UPDATE
}