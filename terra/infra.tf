variable "ci_terraformer" {}
variable "ci_terraformer_creds" {}
variable "staging_sqldb_user_password" {}

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

# # # # # # # # # # #
# LOCAL ENVIRONMENT #
# # # # # # # # # # #

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

# # # # # # # # # # #
# TEST ENVIRONMENT  #
# # # # # # # # # # #

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

# # # # # # # # # # # #
# STAGING ENVIRONMENT #
# # # # # # # # # # # #

resource "google_project" "staging" {
  name = "Env - Staging"
  project_id = "chmsqrt2-truesparrow-staging"
  folder_id = "${google_folder.truesparrow.id}"
  billing_account = "${data.google_billing_account.truesparrow.id}"
}

resource "google_project_services" "staging-services" {
  project = "${google_project.staging.id}"

  services = [
    "maps-embed-backend.googleapis.com",
    "sqladmin.googleapis.com",
    "sql-component.googleapis.com"
  ]
}

resource "google_sql_database_instance" "staging-sqldb-primary" {
  project = "${google_project.staging.id}"

  name = "chmsqrt2-truesparrow-staging-sqldb-primary"
  database_version = "POSTGRES_9_6"
  region = "europe-west1"

  settings {
    tier = "db-f1-micro"
    activation_policy = "ALWAYS"
    availability_type = "ZONAL"
    disk_autoresize = true
    disk_size = 10
    disk_type = "PD_SSD"

    backup_configuration {
      enabled = false
    }

    ip_configuration {
      ipv4_enabled = true
      require_ssl = false # TODO: Or perhaps it should be true
    }

    location_preference {
      zone = "europe-west1-b"
    }

    maintenance_window {
      day = 7
      hour = 6
      update_track = "stable"
    }
  }

  depends_on = [ "google_project_services.staging-services" ]
}

resource "google_sql_user" "staging-sqldb-user" {
  project = "${google_project.staging.id}"
  instance = "${google_sql_database_instance.staging-sqldb-primary.name}"

  name = "truesparrow"
  password = "${var.staging_sqldb_user_password}"
}

# # # # # # # # # # #
# PROD ENVIRONMENT  #
# # # # # # # # # # #

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
