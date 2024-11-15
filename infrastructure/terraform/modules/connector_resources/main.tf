# infrastructure/terraform/modules/connector_resources/main.tf
# CONNECTOR RESOURCES MODULE - CREATES CONNECTOR-SPECIFIC RESOURCES
module "names" {
  source  = "../user_id_helper"
  user_id = var.user_id
}

locals {
  # CLEAN THE CONNECTOR TYPE TO BE GCP COMPLIANT
  connector_type_clean  = lower(replace(var.connector_type, "/[^a-zA-Z0-9]/", ""))
  master_sa            = var.master_service_account
  
  # STANDARDIZED RESOURCE NAMES
  bucket_name             = "${module.names.storage_prefix}-${local.connector_type_clean}"
  ingestion_job_name      = "${module.names.job_prefix}-${local.connector_type_clean}-ingestion"
  transformation_job_name = "${module.names.job_prefix}-${local.connector_type_clean}-transformation"
  scheduler_name          = "${module.names.scheduler_prefix}-${local.connector_type_clean}"

  # DETERMINE IF RESOURCES EXIST
  bucket_exists = length(data.google_storage_bucket.existing_bucket) > 0
  ingestion_job_exists = length(data.google_cloud_run_v2_job.existing_ingestion) > 0
  transformation_job_exists = length(data.google_cloud_run_v2_job.existing_transformation) > 0
}

# CHECK IF BUCKET EXISTS
data "google_storage_bucket" "existing_bucket" {
  count = can(data.google_storage_bucket.existing_bucket_check[0]) ? 1 : 0
  name = local.bucket_name
}

data "google_storage_bucket" "existing_bucket_check" {
  count = 0
  name = local.bucket_name
}

# CREATE CONNECTOR-SPECIFIC STORAGE BUCKET
resource "google_storage_bucket" "connector_bucket" {
  count         = local.bucket_exists ? 0 : 1
  name          = local.bucket_name
  location      = var.region
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      labels,
      lifecycle_rule,
      versioning,
      website
    ]
  }
}

# CHECK IF INGESTION JOB EXISTS
data "google_cloud_run_v2_job" "existing_ingestion" {
  count    = can(data.google_cloud_run_v2_job.existing_ingestion_check[0]) ? 1 : 0
  name     = local.ingestion_job_name
  location = var.region
  project  = var.project_id
}

data "google_cloud_run_v2_job" "existing_ingestion_check" {
  count    = 0
  name     = local.ingestion_job_name
  location = var.region
  project  = var.project_id
}

# CREATE INGESTION JOB
resource "google_cloud_run_v2_job" "ingestion_job" {
  count    = local.ingestion_job_exists ? 0 : 1
  name     = local.ingestion_job_name
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = "gcr.io/${var.project_id}/${lower(var.connector_type)}-ingestion:latest"
        
        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "USER_ID"
          value = var.user_id
        }
      }

      service_account = local.master_sa
      timeout = "3600s"
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      template[0].template[0].containers[0].resources,
      labels
    ]
  }
}

# CHECK IF TRANSFORMATION JOB EXISTS
data "google_cloud_run_v2_job" "existing_transformation" {
  count    = can(data.google_cloud_run_v2_job.existing_transformation_check[0]) ? 1 : 0
  name     = local.transformation_job_name
  location = var.region
  project  = var.project_id
}

data "google_cloud_run_v2_job" "existing_transformation_check" {
  count    = 0
  name     = local.transformation_job_name
  location = var.region
  project  = var.project_id
}

# CREATE TRANSFORMATION JOB
resource "google_cloud_run_v2_job" "transformation_job" {
  count    = local.transformation_job_exists ? 0 : 1
  name     = local.transformation_job_name
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = "gcr.io/${var.project_id}/${lower(var.connector_type)}-transformation:latest"
        
        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "USER_ID"
          value = var.user_id
        }
      }

      service_account = local.master_sa
      timeout = "3600s"
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      template[0].template[0].containers[0].resources,
      labels
    ]
  }
}

# ADD IAM ROLES FOR THE SERVICE ACCOUNT
resource "google_project_iam_member" "ingestion_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${local.master_sa}"
}

# ADD BIGQUERY ACCESS FOR ADMIN
resource "google_bigquery_dataset_iam_member" "admin_raw_access" {
  project    = var.project_id
  dataset_id = module.names.raw_dataset_id
  role       = "roles/bigquery.dataOwner"
  member     = "user:fernando@abcdataz.com"
}

resource "google_bigquery_dataset_iam_member" "admin_transformed_access" {
  project    = var.project_id
  dataset_id = module.names.transformed_dataset_id
  role       = "roles/bigquery.dataOwner"
  member     = "user:fernando@abcdataz.com"
}

# resource "google_project_iam_member" "ingestion_token_encryptor" {
#   project = var.project_id
#   role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
#   member  = "serviceAccount:${local.master_sa}"
# }