#!/bin/bash

# Define the following environment variables:
export SERVICE_NAME=youtube-summarizer-cloud-run
export PROJECT_ID=fussing-around-learning-gcp # change this
export PROJECT_NUMBER=`gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)"`
export REGION=europe-west4  # change this if needed

# Define a title for your OAuth application:
export APP_TITLE="My Youtube Summarizer"

gcloud config set project $PROJECT_ID

# Enable APIs
gcloud services enable \
    iap.googleapis.com \
    cloudresourcemanager.googleapis.com \
    cloudidentity.googleapis.com \
    compute.googleapis.com

# Create IAP Service Account
gcloud beta services identity create \
    --service=iap.googleapis.com \
    --project=$PROJECT_ID

# Create serverless NEG
gcloud compute network-endpoint-groups create $SERVICE_NAME-neg \
    --project $PROJECT_ID \
    --region=$REGION \
    --network-endpoint-type=serverless \
    --cloud-run-service=$SERVICE_NAME

# Create a backend service
gcloud compute backend-services create $SERVICE_NAME-backend \
    --global

# Add the serverless NEG as a backend to the backend service
gcloud compute backend-services add-backend $SERVICE_NAME-backend \
    --global \
    --network-endpoint-group=$SERVICE_NAME-neg \
    --network-endpoint-group-region=$REGION

# Create a URL map to route incoming requests to the backend service
gcloud compute url-maps create $SERVICE_NAME-url-map \
    --default-service $SERVICE_NAME-backend

# Reserve a static IP address
gcloud compute addresses create $SERVICE_NAME-ip \
    --network-tier=PREMIUM \
    --ip-version=IPV4 \
    --global

# Store the nip.io domain
export DOMAIN=$(gcloud compute addresses list --filter $SERVICE_NAME-ip --format='value(ADDRESS)').nip.io

# Create a Google-managed SSL certificate resource
gcloud compute ssl-certificates create $SERVICE_NAME-cert \
    --description=$SERVICE_NAME-cert \
    --domains=$DOMAIN --global

# Create the target HTTPS proxy to route requests to your URL map
gcloud compute target-https-proxies create $SERVICE_NAME-http-proxy \
    --ssl-certificates $SERVICE_NAME-cert \
    --url-map $SERVICE_NAME-url-map

# Create a forwarding rule to route incoming requests to the proxy
gcloud compute forwarding-rules create $SERVICE_NAME-forwarding-rule \
    --load-balancing-scheme=EXTERNAL \
    --network-tier=PREMIUM \
    --address=$SERVICE_NAME-ip \
    --global \
    --ports=443 \
    --target-https-proxy $SERVICE_NAME-http-proxy

# Update the service to only allow ingress traffic from internal requests and requests through HTTP(S) Load Balancer
gcloud run services update $SERVICE_NAME \
    --ingress internal-and-cloud-load-balancing \
    --region $REGION

# Configure OAuth consent screen
export USER_EMAIL=$(gcloud config list account --format "value(core.account)")

gcloud alpha iap oauth-brands create \
    --application_title="$APP_TITLE" \
    --support_email=$USER_EMAIL

# Create an IAP OAuth Client
gcloud alpha iap oauth-clients create \
    projects/$PROJECT_ID/brands/$PROJECT_NUMBER \
    --display_name=$SERVICE_NAME

# Store the client name, ID, and secret
export CLIENT_NAME=$(gcloud alpha iap oauth-clients list \
    projects/$PROJECT_NUMBER/brands/$PROJECT_NUMBER --format='value(name)' \
    --filter="displayName:$SERVICE_NAME")

export CLIENT_ID=${CLIENT_NAME##*/}

export CLIENT_SECRET=$(gcloud alpha iap oauth-clients describe $CLIENT_NAME --format='value(secret)')

# Enable IAP on the backend service
gcloud iap web enable --resource-type=backend-services \
    --oauth2-client-id=$CLIENT_ID \
    --oauth2-client-secret=$CLIENT_SECRET \
    --service=$SERVICE_NAME-backend

# Grant invoker permission to the IAP service account
gcloud run services add-iam-policy-binding $SERVICE_NAME \
    --region=$REGION \
    --member="serviceAccount:service-$PROJECT_NUMBER@gcp-sa-iap.iam.gserviceaccount.com" \
    --role='roles/run.invoker'

# Verify the SSL certificate is ACTIVE:
gcloud compute ssl-certificates list --format='value(MANAGED_STATUS)'

# Get service URL
echo https://$DOMAIN

# # Granting individual user access
# export USER_EMAIL=[USER_EMAIL_ADDRESS]

# gcloud iap web add-iam-policy-binding \
#     --resource-type=backend-services \
#     --service=$SERVICE_NAME-backend \
#     --member=user:$USER_EMAIL \
#     --role='roles/iap.httpsResourceAccessor'

# # Granting group access
# export USER_GROUP=[GROUP_EMAIL_ADDRESS]

# gcloud iap web add-iam-policy-binding \
#     --resource-type=backend-services \
#     --service=$SERVICE_NAME-backend \
#     --member=group:$USER_GROUP \
#     --role='roles/iap.httpsResourceAccessor'

# # Granting access to the entire organization domain
# export ORG_DOMAIN=[YOUR_ORG_DOMAIN]

# gcloud iap web add-iam-policy-binding \
#     --resource-type=backend-services \
#     --service=$SERVICE_NAME-backend \
#     --member=domain:$ORG_DOMAIN \
#     --role='roles/iap.httpsResourceAccessor'