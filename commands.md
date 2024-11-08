# 1. ENABLE ALL REQUIRED APIS
gcloud services enable \
    cloudfunctions.googleapis.com \
    cloudscheduler.googleapis.com \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    eventarc.googleapis.com \
    firestore.googleapis.com

# 2. ADD ALL REQUIRED IAM ROLES
gcloud projects add-iam-policy-binding semantc-sandbox \
    --member="serviceAccount:terraform-sa@semantc-sandbox.iam.gserviceaccount.com" \
    --role="roles/eventarc.eventReceiver"

gcloud projects add-iam-policy-binding semantc-sandbox \
    --member="serviceAccount:terraform-sa@semantc-sandbox.iam.gserviceaccount.com" \
    --role="roles/eventarc.admin"

gcloud projects add-iam-policy-binding semantc-sandbox \
    --member="serviceAccount:terraform-sa@semantc-sandbox.iam.gserviceaccount.com" \
    --role="roles/storage.objectViewer"

gcloud projects add-iam-policy-binding semantc-sandbox \
    --member="serviceAccount:terraform-sa@semantc-sandbox.iam.gserviceaccount.com" \
    --role="roles/run.invoker"

gcloud projects add-iam-policy-binding semantc-sandbox \
    --member="serviceAccount:terraform-sa@semantc-sandbox.iam.gserviceaccount.com" \
    --role="roles/pubsub.publisher"

gcloud projects add-iam-policy-binding semantc-sandbox \
    --member="serviceAccount:terraform-sa@semantc-sandbox.iam.gserviceaccount.com" \
    --role="roles/datastore.viewer"

# 3. ADD EVENTARC SERVICE AGENT PERMISSIONS
gcloud projects add-iam-policy-binding semantc-sandbox \
    --member="serviceAccount:service-685753042420@gcp-sa-eventarc.iam.gserviceaccount.com" \
    --role="roles/eventarc.serviceAgent"

# 4. CREATE AND SETUP TERRAFORM CONFIG BUCKET
gsutil mb -l us-central1 gs://semantc-terraform-configs

# 5. COPY TERRAFORM FILES TO BUCKET
gsutil -m cp -r infrastructure/terraform/* gs://semantc-terraform-configs/

# 6. DEPLOY CLOUD FUNCTION
gcloud functions deploy provision-connector \
    --gen2 \
    --runtime=python39 \
    --region=us-central1 \
    --source=./functions \
    --entry-point=provision_connector \
    --service-account=terraform-sa@semantc-sandbox.iam.gserviceaccount.com \
    --trigger-event-filters="type=google.cloud.firestore.document.v1.written" \
    --trigger-event-filters="document=users/qICP2YhF3IbcHfkK6vX2nwXQBhh2/integrations/connectors" \
    --trigger-event-filters="database=(default)" \
    --trigger-location=nam5 \
    --set-env-vars=FUNCTION_DEBUG=true

# 7. VERIFY SETUP
# CHECK FUNCTION
gcloud functions describe provision-connector --region=us-central1

# CHECK TRIGGER
gcloud eventarc triggers list --location=nam5

# MONITOR LOGS
gcloud functions logs tail provision-connector --region=us-central1