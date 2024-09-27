# terraform/main.tf

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "terraform-state-semantic-dev"
    prefix = "terraform/client_state/unique-client-identifier"  # Replace with your unique client ID
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file(var.terraform_sa_key_path)
}

# Module for Client Resources
module "client_resources" {
  source            = "./modules/client_resources"
  new_client_id     = var.new_client_id
  project_id        = var.project_id
  region            = var.region
  data_location     = var.data_location
  new_client_token  = var.new_client_token
  master_sa_email   = var.master_sa_email
}

# Module for Cloud Run Jobs
module "cloud_run_jobs" {
  source                = "./modules/cloud_run_jobs"
  new_client_id         = var.new_client_id
  project_id            = var.project_id
  region                = var.region
  master_sa_email       = var.master_sa_email
  image_ingestion       = "gcr.io/semantc-dev/xero-ingestion:latest"
  image_transformation  = "gcr.io/semantc-dev/xero-transformation:latest"
}