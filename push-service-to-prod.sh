#!/bin/bash

GOOGLE_APPLICATION_CREDENTIALS=$1
GCP_LIVE_PROJECT=$2
GCP_LIVE_ZONE=$3
SERVICE=$4
VERSION_TAG=$5

gcloud config set project $GCP_LIVE_PROJECT
gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}
gcloud container clusters get-credentials chmsqrt2-truesparrow-live-cluster --zone ${GCP_LIVE_ZONE}
kubectl set image deployment/$SERVICE $SERVICE=eu.gcr.io/chmsqrt2-truesparrow-common/$SERVICE:$VERSION_TAG
