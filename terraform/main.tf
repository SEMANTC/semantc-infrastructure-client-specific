terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "terraform-state-semantc-sandbox"
    prefix = "terraform/state/client"
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = var.terraform_sa_key_path != null ? file(var.terraform_sa_key_path) : null
}

# Module for Tenant Resources
module "tenant_resources" {
  source            = "./modules/tenant_resources"
  new_tenant_id     = var.new_tenant_id
  project_id        = var.project_id
  region            = var.region
  data_location     = var.data_location
  new_tenant_token  = var.new_tenant_token
  master_sa_email   = var.master_sa_email
}

# Module for Cloud Run Jobs
module "cloud_run_jobs" {
  source                = "./modules/cloud_run_jobs"
  new_tenant_id         = var.new_tenant_id
  project_id            = var.project_id
  region                = var.region
  master_sa_email       = var.master_sa_email
  image_ingestion       = "gcr.io/${var.project_id}/xero-ingestion:latest"
  image_transformation  = "gcr.io/${var.project_id}/xero-transformation:latest"

  depends_on = [
    module.tenant_resources  # reference the entire module
  ]
}