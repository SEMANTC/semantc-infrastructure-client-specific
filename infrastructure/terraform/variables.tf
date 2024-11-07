# variables.tf
variable "project_id" {
  description = "gcp project id"
  type        = string
}

variable "region" {
  description = "gcp region"
  type        = string
  default     = "us-central1"
}

variable "user_id" {
  description = "firebase auth user id"
  type        = string
}

variable "terraform_sa_key_path" {
  description = "path to terraform service account key file"
  type        = string
  default     = null
}