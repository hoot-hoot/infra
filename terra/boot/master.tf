# Most of the stuff in here has actually been created by hand when
# doing an initial setup of GCE. Resources _can_ be created when only
# the relevant pieces of data are present, but in reality, that's not
# what happened. I creted everything by hand and then added enough
# resources to mirror my handy-work. You'll thank me later for the pun.

provider "google" {
  # No credentials here. Needs to run as horia@ with default credentials
  # from "gcloud auth application-default login"
}

data "google_organization" "chmsqrt2" {
  domain = "chm-sqrt2.com"
}

data "google_billing_account" "truesparrow" {
  display_name = "TrueSparrow"
  open = true
}

resource "google_folder" "truesparrow" {
  display_name = "TrueSparrow"
  parent = "${data.google_organization.chmsqrt2.name}"
}

resource "google_project" "common" {
  name = "Common"
  project_id = "chmsqrt2-truesparrow-common"
  folder_id = "${google_folder.truesparrow.id}"
  billing_account = "${data.google_billing_account.truesparrow.id}"
}

resource "google_service_account" "ci-terraformer" {
  account_id = "ci-terraformer"
  display_name = "CI Terraformer"
  project = "${google_project.common.id}"
}

resource "google_service_account" "ci-docker-pusher" {
  account_id = "ci-docker-pusher"
display_name = "CI Docker Pusher"
  project = "${google_project.common.id}"
}

resource "google_organization_iam_binding" "chmsqrt2-billing-user" {
  org_id = "${data.google_organization.chmsqrt2.id}"
  role = "roles/billing.user"
  members = [
    "serviceAccount:${google_service_account.ci-terraformer.email}"
  ]
}

resource "google_organization_iam_binding" "chmsqrt2-billing-viewer" {
  org_id = "${data.google_organization.chmsqrt2.id}"
  role = "roles/billing.viewer"
  members = [
    "serviceAccount:${google_service_account.ci-terraformer.email}"
  ]
}

resource "google_organization_iam_binding" "chmsqrt2-browsers" {
  org_id = "${data.google_organization.chmsqrt2.id}"
  role = "roles/browser"
  members = [
    "serviceAccount:${google_service_account.ci-terraformer.email}"
  ]
}

resource "google_folder_iam_binding" "truesparrow-project-creators" {
  folder = "${google_folder.truesparrow.name}"
  role = "roles/resourcemanager.projectCreator"
  members = [
    "serviceAccount:${google_service_account.ci-terraformer.email}"
  ]
}

resource "google_project_iam_binding" "common-viewers" {
  project = "${google_project.common.id}"
  role = "roles/viewer"
  members = [
      "serviceAccount:${google_service_account.ci-terraformer.email}"
  ]
}

resource "google_project_iam_binding" "common-storage-admins" {
  project = "${google_project.common.id}"
  role = "roles/storage.admin"
  members = [
      "serviceAccount:${google_service_account.ci-terraformer.email}",
      "serviceAccount:${google_service_account.ci-docker-pusher.email}"
  ]
}

resource "google_project_services" "common-services" {
  project = "${google_project.common.id}"
  services = [
    # Sure we need them
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",

    # Enabled via UI
    "bigquery-json.googleapis.com",
    "clouddebugger.googleapis.com",
    "datastore.googleapis.com",
    "storage-component.googleapis.com",
    "pubsub.googleapis.com",
    "container.googleapis.com",
    "storage-api.googleapis.com",
    "distance-matrix-backend.googleapis.com",
    "logging.googleapis.com",
    "elevation-backend.googleapis.com",
    "places-backend.googleapis.com",
    "resourceviews.googleapis.com",
    "replicapool.googleapis.com",
    "cloudapis.googleapis.com",
    "sourcerepo.googleapis.com",
    "deploymentmanager.googleapis.com",
    "directions-backend.googleapis.com",
    "containerregistry.googleapis.com",
    "monitoring.googleapis.com",
    "maps-embed-backend.googleapis.com",
    "sql-component.googleapis.com",
    "maps-backend.googleapis.com",
    "cloudtrace.googleapis.com",
    "servicemanagement.googleapis.com",
    "geocoding-backend.googleapis.com",
    "replicapoolupdater.googleapis.com",
    "cloudbuild.googleapis.com"
  ]
}

resource "google_storage_bucket" "terraform-state" {
  name = "chmsqrt2-truesparrow-common-terraform-state"
  project = "${google_project.common.id}"
  storage_class = "MULTI_REGIONAL"
  location = "eu"
  versioning = {
    enabled = true
  }
}

output "terra" {
  value = "${google_service_account.ci-terraformer.email}"
}

output "bill" {
  value = "${data.google_billing_account.truesparrow.id}"
}

output "org_name" {
  value = "${data.google_organization.chmsqrt2.id}"
}

output "flder" {
  value = "${google_folder.truesparrow.id}"
}

output "bucket" {
  value = "${google_storage_bucket.terraform-state.url}"
}