#!/bin/bash

VERSION_TAG=$1

./push-service-to-prod.sh gcp-ci-builder-key.json chmsqrt2-truesparrow-live europe-west1-b sitefe $VERSION_TAG
