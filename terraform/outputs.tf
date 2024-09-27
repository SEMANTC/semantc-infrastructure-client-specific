output "client_service_accounts" {
  description = "mapping of client IDs to their service account emails"
  value = {
    for client_id, module_instance in module.client_resources :
    client_id => module_instance.service_account_email
  }
}

output "client_buckets" {
  description = "mapping of client IDs to their bucket names"
  value = {
    for client_id, module_instance in module.client_resources :
    client_id => module_instance.bucket_name
  }
}

output "client_raw_datasets" {
  description = "mapping of client IDs to their raw dataset IDs"
  value = {
    for client_id, module_instance in module.client_resources :
    client_id => module_instance.raw_dataset_id
  }
}

output "client_transformed_datasets" {
  description = "mapping of client IDs to their transformed dataset IDs"
  value = {
    for client_id, module_instance in module.client_resources :
    client_id => module_instance.transformed_dataset_id
  }
}