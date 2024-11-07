# modules/user_resources/variables.tf
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "user_id" {
  description = "Firebase Auth user ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}