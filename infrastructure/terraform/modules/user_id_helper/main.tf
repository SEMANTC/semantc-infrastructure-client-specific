# infrastructure/terraform/modules/user_id_helper/main.tf
locals {
  # CREATE STANDARDIZED USER ID THAT'S GCP COMPLIANT:
  # 1. TAKE FIRST 8 CHARS OF USER ID (LEAVING ROOM FOR PREFIXES)
  # 2. CONVERT TO LOWERCASE
  # 3. REMOVE ANY NON-ALPHANUMERIC CHARS
  standard_id = lower(replace(substr(var.user_id, 0, 8), "/[^a-zA-Z0-9]/", ""))

  # RESOURCE NAMING PATTERNS COMPLIANT WITH GCP REQUIREMENTS:
  
  # Service Account: 6-30 chars, lowercase letters/numbers/hyphens, start with letter
  service_account_id = "sa-${local.standard_id}"
  
  # BigQuery: letters/numbers/underscores, start with letter/underscore
  raw_dataset_id = "bq_${local.standard_id}_raw"
  transformed_dataset_id = "bq_${local.standard_id}_transformed"
  
  # Storage: 3-63 chars, lowercase letters/numbers/dots/hyphens, start/end with letter/number
  storage_prefix = "gcs-${local.standard_id}"
  
  # Cloud Run: Letters/numbers/hyphens, start with letter
  job_prefix = "job-${local.standard_id}"
  
  # Cloud Scheduler: Letters/numbers/underscores/hyphens, start with letter
  scheduler_prefix = "scheduler-${local.standard_id}"
}