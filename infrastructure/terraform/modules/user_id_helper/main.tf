locals {
  # Create standardized user ID that's GCP compliant:
  # 1. Take first 8 chars of user ID (leaving room for prefixes)
  # 2. Convert to lowercase
  # 3. Remove any non-alphanumeric chars
  standard_id = lower(replace(substr(var.user_id, 0, 8), "/[^a-zA-Z0-9]/", ""))

  # Resource naming patterns compliant with GCP requirements:
  
  # Service Account: 6-30 chars, lowercase letters/numbers/hyphens, start with letter
  service_account_id = "sa-${local.standard_id}"
  
  # BigQuery: Letters/numbers/underscores, start with letter/underscore
  raw_dataset_id = "user_${local.standard_id}_raw"
  transformed_dataset_id = "user_${local.standard_id}_transformed"
  
  # Storage: 3-63 chars, lowercase letters/numbers/dots/hyphens, start/end with letter/number
  storage_prefix = "user-${local.standard_id}"
  
  # Cloud Run: Letters/numbers/hyphens, start with letter
  job_prefix = "job-${local.standard_id}"
  
  # Cloud Scheduler: Letters/numbers/underscores/hyphens, start with letter
  scheduler_prefix = "scheduler-${local.standard_id}"
}