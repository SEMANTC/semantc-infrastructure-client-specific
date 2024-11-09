#!/bin/bash

# Set project ID
export PROJECT_ID=semantc-sandbox
export SA_EMAIL="terraform-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=== VERIFYING SETUP ==="

# Check GCS bucket contents
echo "Checking GCS bucket contents:"
gsutil ls -r gs://semantc-terraform-configs/**

# Verify bucket permissions
echo -e "\nChecking bucket IAM:"
gsutil iam get gs://semantc-terraform-configs

# Check service account permissions
echo -e "\nChecking service account roles:"
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --format='table(bindings.role)' \
    --filter="bindings.members:$SA_EMAIL"

# Verify container images
echo -e "\nChecking container images:"
gcloud container images list --repository=gcr.io/${PROJECT_ID}

# Get the details of the Cloud Function
echo -e "\nCloud Function details:"
gcloud functions describe provision-connector --gen2 --region=us-central1