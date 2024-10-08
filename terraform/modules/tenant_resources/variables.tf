variable "project_id" {
  description = "gcp project ID"
  type        = string
}

variable "region" {
  description = "gcp region"
  type        = string
}

variable "master_sa_email" {
  description = "email of the master service account"
  type        = string
}

variable "data_location" {
  description = "location for data storage services"
  type        = string
}

variable "new_tenant_id" {
  description = "unique identifier for the new tenant"
  type        = string
}

variable "new_tenant_token" {
  type = object({
    access_token  = string
    expires_in    = number
    expires_at    = number
    token_type    = string
    refresh_token = string
    id_token      = string
    scope         = string
  })
  sensitive   = true
  description = "the new tenant's Xero OAuth token"
}