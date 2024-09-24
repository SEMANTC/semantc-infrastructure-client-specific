terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    bucket = "your-terraform-state-bucket"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "client_resources" {
  source  = "./modules/client_resources"
  for_each = toset(var.clients)

  client_id     = each.value
  project_id    = var.project_id
  region        = var.region
  data_location = var.data_location
}

module "cloud_run_jobs" {
  source = "./modules/cloud_run_jobs"
  for_each = toset(var.clients)

  client_id             = each.value
  project_id            = var.project_id
  region                = var.region
  service_account_email = module.client_resources[each.key].service_account_email
  image_ingestion       = "gcr.io/your_project_id/ingestion_image:latest"
  image_transformation  = "gcr.io/your_project_id/transformation_image:latest"
}