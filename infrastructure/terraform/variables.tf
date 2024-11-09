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

variable "connector_type" {
  description = "type of connector (e.g., xero, shopify)"
  type        = string
}