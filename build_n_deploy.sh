#!/bin/sh

set -eu

export INSTRUCTION=${1:-build}
export PROJECT_ID=fussing-around-learning-gcp # change this
export PROJECT_NUMBER=`gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)"`
export SERVICE_NAME=youtube-summarizer-cloud-run # change this if needed
export DEPLOY_REGION=europe-west4  # change this if needed
export PORT=8501  # this should work for streamlit
export IMAGE=$DEPLOY_REGION-docker.pkg.dev/$PROJECT_ID/cloud-run-source-deploy/$SERVICE_NAME
export SERVICE_ACCOUNT=$PROJECT_NUMBER-compute@developer.gserviceaccount.com
export MEMORY=2Gi

if [[ "${INSTRUCTION}" == "build" ]]; then
    gcloud builds submit --tag $IMAGE .
fi

if [[ "${INSTRUCTION}" == "deploy" ]]; then
    # using the default Compute Engine service account
    # (not the best practice as it has broad IAM permissions)
    # alternatively, create a service account and grant it only
    # necessary permissions
    gcloud beta run deploy $SERVICE_NAME --region $DEPLOY_REGION \
    --image $IMAGE \
    --service-account=$SERVICE_ACCOUNT \
    --service-min-instances=1 --min-instances=1 --allow-unauthenticated \
    --project=$PROJECT_ID --port=$PORT --memory=$MEMORY


fi
