# infrastructure/terraform/modules/connector_resources/variables.tf
variable "project_id" {
  description = "gcp project id"
  type        = string
}

variable "region" {
  description = "gcp region"
  type        = string
}

variable "user_id" {
  description = "firebase auth user id"
  type        = string
}

variable "connector_type" {
  description = "type of connector (e.g., xero, shopify)"
  type        = string
}

variable "user_service_account" {
  description = "email of the user's service account"
  type        = string
}