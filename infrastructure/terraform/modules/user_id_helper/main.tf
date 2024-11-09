# HELPER MODULE TO ENSURE CONSISTENT USER ID HANDLING ACROSS ALL MODULES
locals {
  # first generate md5 hash
  raw_hash = md5(var.user_id)
  
  # create different formats for different resources
  bigquery_name = substr(replace(local.raw_hash, "/[^a-zA-Z0-9]/", ""), 0, 12)  # for bigquery (just alphanumeric)
  gcp_name     = "usr-${substr(replace(lower(local.raw_hash), "/[^a-z0-9]/", ""), 0, 12)}" # for gcp resources (starts with letter, allows hyphens)
}

# output both formats
output "bigquery_name" {
  value = local.bigquery_name
}

output "gcp_name" {
  value = local.gcp_name
}

variable "user_id" {
  description = "Firebase auth user id"
  type        = string
}