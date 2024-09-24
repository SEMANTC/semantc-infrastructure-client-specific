output "master_service_account_email" {
  description = "Email of the master service account"
  value       = google_service_account.master_sa.email
}

output "client_service_accounts" {
  description = "Mapping of client IDs to their service account emails"
  value = {
    for client_id, module_instance in module.client_resources :
    client_id => module_instance.service_account_email
  }
}

output "client_buckets" {
  description = "Mapping of client IDs to their bucket names"
  value = {
    for client_id, module_instance in module.client_resources :
    client_id => module_instance.bucket_name
  }
}

output "client_raw_datasets" {
  description = "Mapping of client IDs to their raw dataset IDs"
  value = {
    for client_id, module_instance in module.client_resources :
    client_id => module_instance.raw_dataset_id
  }
}

output "client_transformed_datasets" {
  description = "Mapping of client IDs to their transformed dataset IDs"
  value = {
    for client_id, module_instance in module.client_resources :
    client_id => module_instance.transformed_dataset_id
  }
}