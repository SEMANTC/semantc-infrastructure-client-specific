# terraform/variables
variable "terraform_sa_key_path" {
  description = "path to the terraform service account key json file"
  type        = string
  default     = null
}

variable "project_id" {
  description = "gcp project id"
  type        = string
  default     = "semantc-sandbox"
}

variable "region" {
  description = "gcp region"
  type        = string
  default     = "us-central1"
}

variable "master_sa_email" {
  description = "master service account email"
  type        = string
  default     = "master-sa@semantc-sandbox.iam.gserviceaccount.com"
}

variable "data_location" {
  description = "location for data storage services"
  type        = string
  default     = "US"
}

# Existing variables
variable "new_tenant_id" {
  description = "unique tenant identifier"
  type        = string
}

variable "new_tenant_token" {
  type = object({
    access_token  = string
    expires_in    = number
    expires_at    = number
    token_type    = string
    refresh_token = string
    id_token      = string
    scope         = string
  })
  sensitive   = true
  description = "the new tenant's xero oauth token"
}