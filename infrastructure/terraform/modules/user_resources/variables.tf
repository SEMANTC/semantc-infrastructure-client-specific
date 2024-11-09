# infrastructure/terraform/modules/user_resources/variables.tf
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "user_id" {
  description = "firebase auth user id"
  type        = string
}

variable "region" {
  description = "gcp region"
  type        = string
}