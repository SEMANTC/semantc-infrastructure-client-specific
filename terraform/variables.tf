variable "terraform_sa_key_path" {
  description = "Path to the Terraform service account key JSON file"
  type        = string
  default     = null
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "semantc-dev"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "master_sa_email" {
  description = "Master Service Account Email"
  type        = string
  default     = "master-sa@semantc-dev.iam.gserviceaccount.com"
}

variable "data_location" {
  description = "Location for data storage services"
  type        = string
  default     = "US"
}

# Existing variables
variable "new_client_id" {
  description = "Unique Client Identifier"
  type        = string
}

variable "new_client_token" {
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
  description = "the new client's Xero OAuth token"
}