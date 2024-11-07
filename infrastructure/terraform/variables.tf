# variables.tf
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "user_id" {
  description = "Firebase Auth user ID"
  type        = string
}

variable "terraform_sa_key_path" {
  description = "Path to Terraform service account key file"
  type        = string
  default     = null
}