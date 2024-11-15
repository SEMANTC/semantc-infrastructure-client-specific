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
  description = "user id from firebase auth"
  type        = string
}

variable "connector_type" {
  description = "type of connector (e.g., xero, shopify)"
  type        = string
}

variable "master_service_account" {
  description = "master service account email that will run the cloud run jobs"
  type        = string
}