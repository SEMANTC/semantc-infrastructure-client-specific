# modules/connector_resources/variables.tf
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

variable "connector_type" {
  description = "Type of connector (e.g., xero, shopify)"
  type        = string
}

variable "connector_config" {
  description = "Connector configuration from Firestore"
  type        = map(any)
}

variable "connector_credentials" {
  description = "Connector credentials from Firestore"
  type        = map(any)
  sensitive   = true
}

variable "user_service_account" {
  description = "Email of the user's service account"
  type        = string
}

variable "ingestion_image" {
  description = "Container image for ingestion job"
  type        = string
  default     = "gcr.io/project-id/ingestion:latest"
}

variable "transformation_image" {
  description = "Container image for transformation job"
  type        = string
  default     = "gcr.io/project-id/transformation:latest"
}