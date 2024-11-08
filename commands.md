gsutil -m cp -r infrastructure/terraform/* gs://semantc-terraform-configs/

# 1.ŹENABLE REQUIRED APIS
gcloud services enable \
    cloudfunctions.googleapis.com \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    firestore.googleapis.com

# 2. CREATE BUCKET AND COPY TERRAFORM FILES
gsutil mb -l us-central1 gs://semantc-terraform-configs
gsutil -m cp -r infrastructure/terraform/* gs://semantc-terraform-configs/

# 3. DEPLOY FUNCTION WITH HTTP TRIGGER
gcloud functions deploy provision-connector \
    --gen2 \
    --runtime=python39 \
    --region=us-central1 \
    --source=./functions \
    --entry-point=provision_connector \
    --service-account=terraform-sa@semantc-sandbox.iam.gserviceaccount.com \
    --trigger-http \
    --allow-unauthenticated \
    --memory=512MB \
    --timeout=540s

# 4. TEST THE DEPLOYMENT
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"userId":"qICP2YhF3IbcHfkK6vX2nwXQBhh2"}' \
  https://us-central1-semantc-sandbox.cloudfunctions.net/provision-connector

# 5. MONITOR LOGS
gcloud functions logs read provision-connector --region=us-central1