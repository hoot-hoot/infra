variable "ci_terraformer" {}
variable "ci_terraformer_creds" {}

terraform {
  backend "gcs" {
    project = "chmsqrt2-truesparrow-common"
    bucket = "chmsqrt2-truesparrow-common-terraform-state"
    prefix = "state/infra"
    credentials = "./ci-terraformer-creds.json"
  }
}

provider "google" {
  credentials = "${file(var.ci_terraformer_creds)}"
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

resource "google_project" "local" {
  name = "Env - Local"
  project_id = "chmsqrt2-truesparrow-local"
  folder_id = "${google_folder.truesparrow.id}"
  billing_account = "${data.google_billing_account.truesparrow.id}"
}

resource "google_project_services" "local-services" {
  project = "${google_project.local.id}"
  services = [
    "maps-embed-backend.googleapis.com"
  ]
}

resource "google_project" "test" {
  name = "Env - Test"
  project_id = "chmsqrt2-truesparrow-test"
  folder_id = "${google_folder.truesparrow.id}"
  billing_account = "${data.google_billing_account.truesparrow.id}"
}

resource "google_project_services" "test-services" {
  project = "${google_project.test.id}"
  services = [
    "maps-embed-backend.googleapis.com"
  ]
}

resource "google_project" "staging" {
  name = "Env - Staging"
  project_id = "chmsqrt2-truesparrow-staging"
  folder_id = "${google_folder.truesparrow.id}"
  billing_account = "${data.google_billing_account.truesparrow.id}"
}

resource "google_project_services" "staging-services" {
  project = "${google_project.staging.id}"
  services = [
    "maps-embed-backend.googleapis.com"
  ]
}

resource "google_project" "prod" {
  name = "Env - Prod"
  project_id = "chmsqrt2-truesparrow-prod"
  folder_id = "${google_folder.truesparrow.id}"
  billing_account = "${data.google_billing_account.truesparrow.id}"
}

resource "google_project_services" "prod-services" {
  project = "${google_project.prod.id}"
  services = [
    "maps-embed-backend.googleapis.com"
  ]
}
