output "client_service_accounts" {
  value = {
    for client_id, module_instance in module.client_resources :
    client_id => module_instance.service_account_email
  }
}

output "client_buckets" {
  value = {
    for client_id, module_instance in module.client_resources :
    client_id => module_instance.bucket_name
  }
}

output "client_raw_datasets" {
  value = {
    for client_id, module_instance in module.client_resources :
    client_id => module_instance.raw_dataset_id
  }
}

output "client_transformed_datasets" {
  value = {
    for client_id, module_instance in module.client_resources :
    client_id => module_instance.transformed_dataset_id
  }
}