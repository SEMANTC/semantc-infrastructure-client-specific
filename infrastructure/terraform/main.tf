# infrastructure/terraform/main.tf
terraform {
  required_version = ">= 1.5.7"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# CREATE USER'S SERVICE ACCOUNT AND DATASETS
module "user_resources" {
  source     = "./modules/user_resources"
  project_id = var.project_id
  user_id    = var.user_id
  region     = var.region
}

# CREATE CONNECTOR-SPECIFIC RESOURCES (CLOUD RUN JOBS, STORAGE)
module "connector_resources" {
  source                  = "./modules/connector_resources"
  project_id              = var.project_id
  user_id                 = var.user_id
  region                  = var.region
  connector_type          = var.connector_type
  master_service_account  = "master-sa@semantc-sandbox.iam.gserviceaccount.com"
  
  depends_on = [module.user_resources]
}