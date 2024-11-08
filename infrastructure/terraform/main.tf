# main.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "terraform-state-semantc-sandbox"
    prefix = "terraform/state/users"
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
}

provider "google-beta" {
  project     = var.project_id
  region      = var.region
}

# CREATE BASE USER RESOURCES (SERVICE ACCOUNT, IAM)
module "user_resources" {
  source     = "./modules/user_resources"
  project_id = var.project_id
  user_id    = var.user_id
  region     = var.region
}

# CREATE CONNECTOR-SPECIFIC RESOURCES FOR EACH ACTIVE CONNECTOR
module "connector_resources" {
  source = "./modules/connector_resources"
  
  project_id = var.project_id
  user_id    = var.user_id
  region     = var.region
  
  connector_type = "xero"

  user_service_account = module.user_resources.service_account_email
  
  depends_on = [module.user_resources]
}

# SETUP BIGQUERY ACCESS
module "bigquery_access" {
  source = "./modules/bigquery_access"
  
  project_id = var.project_id
  user_id    = var.user_id
  service_account_email = module.user_resources.service_account_email
  
  depends_on = [module.user_resources]
}
