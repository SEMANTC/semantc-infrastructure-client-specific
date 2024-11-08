# modules/connector_resources/variables.tf
variable "project_id" {
  description = "gcp project id"
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

variable "connector_type" {
  description = "type of connector (e.g., xero, shopify)"
  type        = string
}

variable "user_service_account" {
  description = "email of the user's service account"
  type        = string
}

variable "ingestion_image" {
  description = "container image for ingestion job"
  type        = string
  default     = "gcr.io/project-id/ingestion:latest"
}

variable "transformation_image" {
  description = "container image for transformation job"
  type        = string
  default     = "gcr.io/project-id/transformation:latest"
}