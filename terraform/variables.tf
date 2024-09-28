variable "terraform_sa_key_path" {
  description = "path to the Terraform service account key JSON file"
  type        = string
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
  description = "Secure Client Token"
  type        = string
}