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

# FIRESTORE DATA SOURCE FOR CONNECTOR CONFIGURATION
data "google_firestore_document" "connectors" {
  project    = var.project_id
  collection = "users/${var.user_id}/integrations"
  document_id = "connectors"
}

data "google_firestore_document" "credentials" {
  project    = var.project_id
  collection = "users/${var.user_id}/integrations"
  document_id = "credentials"
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
  for_each = {
    for k, v in jsondecode(data.google_firestore_document.connectors.fields).connectors.mapValue.fields :
    k => v if v.mapValue.fields.active.booleanValue == true
  }

  source = "./modules/connector_resources"
  
  project_id = var.project_id
  user_id    = var.user_id
  region     = var.region
  
  connector_type = each.key
  connector_config = each.value.mapValue.fields
  connector_credentials = jsondecode(data.google_firestore_document.credentials.fields)[each.key]
  
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
