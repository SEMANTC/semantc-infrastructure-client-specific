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
  bucket_name             = "${var.project_id}-${module.names.storage_prefix}-${local.connector_type_clean}"
  ingestion_job_name      = "${module.names.job_prefix}-${local.connector_type_clean}-ingestion"
  transformation_job_name = "${module.names.job_prefix}-${local.connector_type_clean}-transformation"
  scheduler_name          = "${module.names.scheduler_prefix}-${local.connector_type_clean}"
}

# CHECK IF BUCKET EXISTS
data "google_storage_bucket" "existing_bucket" {
  name = local.bucket_name
}

# CREATE CONNECTOR-SPECIFIC STORAGE BUCKET
resource "google_storage_bucket" "connector_bucket" {
  count         = data.google_storage_bucket.existing_bucket == null ? 1 : 0
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
  name     = local.ingestion_job_name
  location = var.region
  project  = var.project_id
}

# CREATE INGESTION JOB
resource "google_cloud_run_v2_job" "ingestion_job" {
  count    = data.google_cloud_run_v2_job.existing_ingestion == null ? 1 : 0
  name     = local.ingestion_job_name
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = "gcr.io/${var.project_id}/${lower(var.connector_type)}-ingestion:latest"
        
        env {
          name  = "USER_ID"
          value = var.user_id
        }
        
        env {
          name  = "PROJECT_ID"
          value = var.project_id
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
  name     = local.transformation_job_name
  location = var.region
  project  = var.project_id
}

# CREATE TRANSFORMATION JOB
resource "google_cloud_run_v2_job" "transformation_job" {
  count    = data.google_cloud_run_v2_job.existing_transformation == null ? 1 : 0
  name     = local.transformation_job_name
  location = var.region
  project  = var.project_id

  template {
    template {
      containers {
        image = "gcr.io/${var.project_id}/${lower(var.connector_type)}-transformation:latest"
        
        env {
          name  = "USER_ID"
          value = var.user_id
        }

        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "RAW_DATASET"
          value = module.names.raw_dataset_id
        }

        env {
          name  = "TRANSFORMED_DATASET"
          value = module.names.transformed_dataset_id
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
