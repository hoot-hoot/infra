variable "ci_terraformer" {}
variable "ci_terraformer_creds" {}
variable "container_registry_bucket" {}
variable "staging_region" {}
variable "staging_region_and_zone" {}
variable "staging_sqldb_main_user_identity_password" {}
variable "staging_sqldb_main_user_content_password" {}
variable "staging_compute_web_cluster_user_password" {}
variable "live_region" {}
variable "live_region_and_zone" {}
variable "live_sqldb_main_user_identity_password" {}
variable "live_sqldb_main_user_content_password" {}
variable "live_compute_web_cluster_user_password" {}

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

# # # # #
# DATA  #
# # # # #

data "google_organization" "chmsqrt2" {
  domain = "chm-sqrt2.com"
}

data "google_billing_account" "truesparrow" {
  display_name = "TrueSparrow"
  open = true
}

data "google_active_folder" "truesparrow" {
  display_name = "TrueSparrow"
  parent = "${data.google_organization.chmsqrt2.name}"
}

data "google_project" "common" {
  project_id = "chmsqrt2-truesparrow-common"
}

data "google_dns_managed_zone" "chmsqrt2-domain" {
   name = "chmsqrt2-domain"
   project = "${data.google_project.common.id}"
}

# # # # # #
# COMMON  #
# # # # # #

resource "google_storage_bucket_iam_binding" "container-registry-storage-object-viewers" {
  bucket = "${var.container_registry_bucket}"
  role = "roles/storage.objectViewer"
  members = [
    "serviceAccount:${google_service_account.staging-compute-web.email}",
    "serviceAccount:${google_service_account.live-compute-web.email}"
  ]
}

# # # # # # # # # # #
# LOCAL ENVIRONMENT #
# # # # # # # # # # #

resource "google_project" "local" {
  name = "Env - Local"
  project_id = "chmsqrt2-truesparrow-local"
  folder_id = "${data.google_active_folder.truesparrow.id}"
  billing_account = "${data.google_billing_account.truesparrow.id}"
}

resource "google_project_services" "local-services" {
  project = "${google_project.local.id}"
  services = [
    "maps-embed-backend.googleapis.com",
    "maps-backend.googleapis.com",
    "places-backend.googleapis.com"
  ]
}

# # # # # # # # # # #
# TEST ENVIRONMENT  #
# # # # # # # # # # #

resource "google_project" "test" {
  name = "Env - Test"
  project_id = "chmsqrt2-truesparrow-test"
  folder_id = "${data.google_active_folder.truesparrow.id}"
  billing_account = "${data.google_billing_account.truesparrow.id}"
}

resource "google_project_services" "test-services" {
  project = "${google_project.test.id}"
  services = [
    "maps-embed-backend.googleapis.com",
    "maps-backend.googleapis.com",
    "places-backend.googleapis.com"
  ]
}

# # # # # # # # # # # #
# STAGING ENVIRONMENT #
# # # # # # # # # # # #

resource "google_project" "staging" {
  name = "Env - Staging"
  project_id = "chmsqrt2-truesparrow-staging"
  folder_id = "${data.google_active_folder.truesparrow.id}"
  billing_account = "${data.google_billing_account.truesparrow.id}"
}

resource "google_project_services" "staging-services" {
  project = "${google_project.staging.id}"

  services = [
    "compute.googleapis.com",
    "dns.googleapis.com",
    "maps-embed-backend.googleapis.com",
    "maps-backend.googleapis.com",
    "places-backend.googleapis.com",
    "sqladmin.googleapis.com",
    "sql-component.googleapis.com",
    "containerregistry.googleapis.com",
    "pubsub.googleapis.com",
    "deploymentmanager.googleapis.com",
    "replicapool.googleapis.com",
    "replicapoolupdater.googleapis.com",
    "resourceviews.googleapis.com",
    "container.googleapis.com",
    "storage-api.googleapis.com"
  ]
}

resource "google_service_account" "staging-compute-web" {
  account_id = "compute-web"
  display_name = "Compute Web"
  project = "${google_project.staging.id}"
}

resource "google_service_account" "staging-service-identity" {
  account_id = "service-identity"
  display_name = "Identity Service"
  project = "${google_project.staging.id}"
}

resource "google_service_account" "staging-service-content" {
  account_id = "service-content"
  display_name = "Content Service"
  project = "${google_project.staging.id}"
}

resource "google_service_account" "staging-service-adminfe" {
  account_id = "service-adminfe"
  display_name = "Adminfe Service"
  project = "${google_project.staging.id}"
}

resource "google_service_account" "staging-service-sitefe" {
  account_id = "service-sitefe"
  display_name = "Sitefe Service"
  project = "${google_project.staging.id}"
}

resource "google_project_iam_binding" "staging-cloudsql-clients" {
  project = "${google_project.staging.id}"
  role = "roles/cloudsql.client"
  members = [
    "serviceAccount:${google_service_account.staging-service-identity.email}",
    "serviceAccount:${google_service_account.staging-service-content.email}"
  ]
}

resource "google_compute_network" "staging-network" {
  project = "${google_project.staging.id}"

  name = "chmsqrt2-truesparrow-staging-network"
  description = "Common network"
  auto_create_subnetworks = false
  routing_mode = "REGIONAL"

  depends_on = [ "google_project_services.staging-services" ]
}

resource "google_compute_subnetwork" "staging-subnetwork" {
  project = "${google_project.staging.id}"
  network = "${google_compute_network.staging-network.name}"

  name = "chmsqrt2-truesparrow-staging-subnetwork"
  description = "Subnetwork in the default staging zone"
  region = "${var.staging_region}"
  ip_cidr_range = "10.10.0.0/16"
  private_ip_google_access = true

  secondary_ip_range {
    range_name = "staging-cluster-pods"
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name = "staging-cluster-services"
    ip_cidr_range = "10.30.0.0/16"
  }
}

resource "google_compute_firewall" "staging-network-firewall" {
  project = "${google_project.staging.id}"
  network = "${google_compute_network.staging-network.name}"

  name = "chmsqrt2-truesparrow-staging-network-firewall"
  description = "The firewall rules for the common network"

  priority = 1000
  direction = "INGRESS"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports = [ 22, 80, 443 ] # SSH
  }
}

resource "google_sql_database_instance" "staging-sqldb-main" {
  project = "${google_project.staging.id}"

  name = "chmsqrt2-truesparrow-staging-sqldb-main"
  database_version = "POSTGRES_9_6"
  region = "${var.staging_region}"

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

resource "google_sql_user" "staging-sqldb-user-identity" {
  project = "${google_project.staging.id}"
  instance = "${google_sql_database_instance.staging-sqldb-main.name}"

  name = "service-identity"
  password = "${var.staging_sqldb_main_user_identity_password}"
}

resource "google_sql_user" "staging-sqldb-user-content" {
  project = "${google_project.staging.id}"
  instance = "${google_sql_database_instance.staging-sqldb-main.name}"

  name = "service-content"
  password = "${var.staging_sqldb_main_user_content_password}"
}

resource "google_sql_database" "staging-sqldb-database" {
  project = "${google_project.staging.id}"
  instance = "${google_sql_database_instance.staging-sqldb-main.name}"

  name = "truesparrow"
  charset = "UTF8"
  collation = "en_US.UTF8"

  depends_on = [
    "google_sql_user.staging-sqldb-user-identity",
    "google_sql_user.staging-sqldb-user-content"
  ]
}


resource "google_container_cluster" "staging-cluster" {
  project = "${google_project.staging.id}"
  zone = "${var.staging_region_and_zone}"

  name = "chmsqrt2-truesparrow-staging-cluster"
  description = "The common cluster for all the services"
  min_master_version = "1.9.4-gke.1"
  node_version = "1.9.4-gke.1"

  network = "${google_compute_network.staging-network.self_link}"
  subnetwork = "${google_compute_subnetwork.staging-subnetwork.name}"
  ip_allocation_policy {
    cluster_secondary_range_name = "staging-cluster-pods"
    services_secondary_range_name = "staging-cluster-services"
  }

  logging_service = "logging.googleapis.com"
  monitoring_service = "monitoring.googleapis.com"

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  master_auth {
    username = "truesparrow"
    password = "${var.staging_compute_web_cluster_user_password}"
  }

  node_pool {
    name = "chmsqrt2-truesparrow-staging-pool"

    initial_node_count = 1
    autoscaling {
      min_node_count = 1
      max_node_count = 1
    }

    management {
      auto_repair = false
      auto_upgrade = true
    }

    node_config {
      oauth_scopes = [
        "https://www.googleapis.com/auth/compute",
        "https://www.googleapis.com/auth/devstorage.read_only",
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring",
      ]

      disk_size_gb = 10
      local_ssd_count = 0
      machine_type = "n1-highcpu-2"
      preemptible = false

      service_account = "${google_service_account.staging-compute-web.email}"
    }
  }
}

resource "google_project_iam_binding" "staging-container-cluster-admins" {
  project = "${google_project.staging.id}"
  role = "roles/container.clusterAdmin"
  # TODO: perhaps dont hardcode this in the future
  members = [
      "serviceAccount:ci-builder@chmsqrt2-truesparrow-common.iam.gserviceaccount.com"
  ]
}

resource "google_project_iam_binding" "staging-container-developer" {
  project = "${google_project.staging.id}"
  role = "roles/container.developer"
  # TODO: perhaps dont hardcode this in the future
  members = [
      "serviceAccount:ci-builder@chmsqrt2-truesparrow-common.iam.gserviceaccount.com"
  ]
}

resource "google_compute_global_address" "staging-loadbalancer-address" {
  project = "${google_project.staging.id}"

  name = "chmsqrt2-truesparrow-staging-loadbalancer-address"
  ip_version = "IPV4"
}

resource "google_dns_record_set" "staging-adminfe-domain" {
  project = "${data.google_project.common.id}"
  managed_zone = "${data.google_dns_managed_zone.chmsqrt2-domain.name}"

  name = "adminfe.staging.truesparrow.${data.google_dns_managed_zone.chmsqrt2-domain.dns_name}"
  type = "A"
  ttl = "300"
  rrdatas = [ "${google_compute_global_address.staging-loadbalancer-address.address}" ]
}

resource "google_dns_record_set" "staging-sitefe-domain" {
  project = "${data.google_project.common.id}"
  managed_zone = "${data.google_dns_managed_zone.chmsqrt2-domain.name}"

  name = "sitefe.staging.truesparrow.${data.google_dns_managed_zone.chmsqrt2-domain.dns_name}"
  type = "A"
  ttl = "300"
  rrdatas = [ "${google_compute_global_address.staging-loadbalancer-address.address}" ]
}

resource "google_dns_record_set" "staging-sitefe-wildcard-domain" {
  project = "${data.google_project.common.id}"
  managed_zone = "${data.google_dns_managed_zone.chmsqrt2-domain.name}"

  name = "*.sitefe.staging.truesparrow.${data.google_dns_managed_zone.chmsqrt2-domain.dns_name}"
  type = "A"
  ttl = "300"
  rrdatas = [ "${google_compute_global_address.staging-loadbalancer-address.address}" ]
}

resource "google_dns_record_set" "staging-adminfe-letsencrypt-challange" {
  project = "${data.google_project.common.id}"
  managed_zone = "${data.google_dns_managed_zone.chmsqrt2-domain.name}"

  name = "_acme-challenge.adminfe.staging.truesparrow.${data.google_dns_managed_zone.chmsqrt2-domain.dns_name}"
  type = "TXT"
  ttl = "3600"
  rrdatas = [ "QWam06PBFvci_TppFzcIOcmNLC--gWaLkythS3yUsjE" ]
}

resource "google_dns_record_set" "staging-sitefe-letsencrypt-challange" {
  project = "${data.google_project.common.id}"
  managed_zone = "${data.google_dns_managed_zone.chmsqrt2-domain.name}"

  name = "_acme-challenge.sitefe.staging.truesparrow.${data.google_dns_managed_zone.chmsqrt2-domain.dns_name}"
  type = "TXT"
  ttl = "3600"
  rrdatas = [ "9uC_pYUkVe27ldkOqRSSmLYQVyj2o7JGl7upnnDyltQ", "UmxjwgMiLLSF0WbgpugcDUJ-xVqB5dwEhvcvZTQp7tw" ]
}

resource "google_compute_ssl_certificate" "staging-loadbalancer-newnew-certificate" {
  project = "${google_project.staging.id}"

  name = "chmsqrt2-truesparrow-staging-loadbalancer-newnew-certificate"
  description = "Certificate for the staging global loadbalancer"

  private_key = "${file("../certs-staging/privkey.pem")}"
  certificate = "${file("../certs-staging/fullchain.pem")}"
}

# # # # # # # # # # #
# LIVE ENVIRONMENT  #
# # # # # # # # # # #

resource "google_project" "live" {
  name = "Env - Live"
  project_id = "chmsqrt2-truesparrow-live"
  folder_id = "${data.google_active_folder.truesparrow.id}"
  billing_account = "${data.google_billing_account.truesparrow.id}"
}

resource "google_project_services" "live-services" {
  project = "${google_project.live.id}"

  services = [
    "compute.googleapis.com",
    "dns.googleapis.com",
    "maps-embed-backend.googleapis.com",
    "maps-backend.googleapis.com",
    "places-backend.googleapis.com",
    "sqladmin.googleapis.com",
    "sql-component.googleapis.com",
    "containerregistry.googleapis.com",
    "pubsub.googleapis.com",
    "deploymentmanager.googleapis.com",
    "replicapool.googleapis.com",
    "replicapoolupdater.googleapis.com",
    "resourceviews.googleapis.com",
    "container.googleapis.com",
    "storage-api.googleapis.com"
  ]
}

resource "google_service_account" "live-compute-web" {
  account_id = "compute-web"
  display_name = "Compute Web"
  project = "${google_project.live.id}"
}

resource "google_service_account" "live-service-identity" {
  account_id = "service-identity"
  display_name = "Identity Service"
  project = "${google_project.live.id}"
}

resource "google_service_account" "live-service-content" {
  account_id = "service-content"
  display_name = "Content Service"
  project = "${google_project.live.id}"
}

resource "google_service_account" "live-service-adminfe" {
  account_id = "service-adminfe"
  display_name = "Adminfe Service"
  project = "${google_project.live.id}"
}

resource "google_service_account" "live-service-sitefe" {
  account_id = "service-sitefe"
  display_name = "Sitefe Service"
  project = "${google_project.live.id}"
}

resource "google_project_iam_binding" "live-cloudsql-clients" {
  project = "${google_project.live.id}"
  role = "roles/cloudsql.client"
  members = [
    "serviceAccount:${google_service_account.live-service-identity.email}",
    "serviceAccount:${google_service_account.live-service-content.email}"
  ]
}

resource "google_compute_network" "live-network" {
  project = "${google_project.live.id}"

  name = "chmsqrt2-truesparrow-live-network"
  description = "Common network"
  auto_create_subnetworks = false
  routing_mode = "REGIONAL"

  depends_on = [ "google_project_services.live-services" ]
}

resource "google_compute_subnetwork" "live-subnetwork" {
  project = "${google_project.live.id}"
  network = "${google_compute_network.live-network.name}"

  name = "chmsqrt2-truesparrow-live-subnetwork"
  description = "Subnetwork in the default live zone"
  region = "${var.live_region}"
  ip_cidr_range = "10.10.0.0/16"
  private_ip_google_access = true

  secondary_ip_range {
    range_name = "live-cluster-pods"
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name = "live-cluster-services"
    ip_cidr_range = "10.30.0.0/16"
  }
}

resource "google_compute_firewall" "live-network-firewall" {
  project = "${google_project.live.id}"
  network = "${google_compute_network.live-network.name}"

  name = "chmsqrt2-truesparrow-live-network-firewall"
  description = "The firewall rules for the common network"

  priority = 1000
  direction = "INGRESS"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports = [ 22, 80, 443 ] # SSH
  }
}

resource "google_sql_database_instance" "live-sqldb-main" {
  project = "${google_project.live.id}"

  name = "chmsqrt2-truesparrow-live-sqldb-main"
  database_version = "POSTGRES_9_6"
  region = "${var.live_region}"

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

  depends_on = [ "google_project_services.live-services" ]
}

resource "google_sql_user" "live-sqldb-user-identity" {
  project = "${google_project.live.id}"
  instance = "${google_sql_database_instance.live-sqldb-main.name}"

  name = "service-identity"
  password = "${var.live_sqldb_main_user_identity_password}"
}

resource "google_sql_user" "live-sqldb-user-content" {
  project = "${google_project.live.id}"
  instance = "${google_sql_database_instance.live-sqldb-main.name}"

  name = "service-content"
  password = "${var.live_sqldb_main_user_content_password}"
}

resource "google_sql_database" "live-sqldb-database" {
  project = "${google_project.live.id}"
  instance = "${google_sql_database_instance.live-sqldb-main.name}"

  name = "truesparrow"
  charset = "UTF8"
  collation = "en_US.UTF8"

  depends_on = [
    "google_sql_user.live-sqldb-user-identity",
    "google_sql_user.live-sqldb-user-content"
  ]
}

resource "google_container_cluster" "live-cluster" {
  project = "${google_project.live.id}"
  zone = "${var.live_region_and_zone}"

  name = "chmsqrt2-truesparrow-live-cluster"
  description = "The common cluster for all the services"
  min_master_version = "1.9.4-gke.1"
  node_version = "1.9.4-gke.1"

  network = "${google_compute_network.live-network.self_link}"
  subnetwork = "${google_compute_subnetwork.live-subnetwork.name}"
  ip_allocation_policy {
    cluster_secondary_range_name = "live-cluster-pods"
    services_secondary_range_name = "live-cluster-services"
  }

  logging_service = "logging.googleapis.com"
  monitoring_service = "monitoring.googleapis.com"

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  master_auth {
    username = "truesparrow"
    password = "${var.live_compute_web_cluster_user_password}"
  }

  node_pool {
    name = "chmsqrt2-truesparrow-live-pool"

    initial_node_count = 1
    autoscaling {
      min_node_count = 1
      max_node_count = 1
    }

    management {
      auto_repair = false
      auto_upgrade = true
    }

    node_config {
      oauth_scopes = [
        "https://www.googleapis.com/auth/compute",
        "https://www.googleapis.com/auth/devstorage.read_only",
        "https://www.googleapis.com/auth/logging.write",
        "https://www.googleapis.com/auth/monitoring",
      ]

      disk_size_gb = 10
      local_ssd_count = 0
      machine_type = "n1-highcpu-2"
      preemptible = false

      service_account = "${google_service_account.live-compute-web.email}"
    }
  }
}

resource "google_project_iam_binding" "live-container-cluster-admins" {
  project = "${google_project.live.id}"
  role = "roles/container.clusterAdmin"
  # TODO: perhaps dont hardcode this in the future
  members = [
      "serviceAccount:ci-builder@chmsqrt2-truesparrow-common.iam.gserviceaccount.com"
  ]
}

resource "google_project_iam_binding" "live-container-developer" {
  project = "${google_project.live.id}"
  role = "roles/container.developer"
  # TODO: perhaps dont hardcode this in the future
  members = [
      "serviceAccount:ci-builder@chmsqrt2-truesparrow-common.iam.gserviceaccount.com"
  ]
}

resource "google_compute_global_address" "live-loadbalancer-address" {
  project = "${google_project.live.id}"

  name = "chmsqrt2-truesparrow-live-loadbalancer-address"
  ip_version = "IPV4"
}

resource "google_dns_record_set" "live-adminfe-domain" {
  project = "${data.google_project.common.id}"
  managed_zone = "${data.google_dns_managed_zone.chmsqrt2-domain.name}"

  name = "adminfe.live.truesparrow.${data.google_dns_managed_zone.chmsqrt2-domain.dns_name}"
  type = "A"
  ttl = "300"
  rrdatas = [ "${google_compute_global_address.live-loadbalancer-address.address}" ]
}

resource "google_dns_record_set" "live-sitefe-domain" {
  project = "${data.google_project.common.id}"
  managed_zone = "${data.google_dns_managed_zone.chmsqrt2-domain.name}"

  name = "sitefe.live.truesparrow.${data.google_dns_managed_zone.chmsqrt2-domain.dns_name}"
  type = "A"
  ttl = "300"
  rrdatas = [ "${google_compute_global_address.live-loadbalancer-address.address}" ]
}

resource "google_dns_record_set" "live-sitefe-wildcard-domain" {
  project = "${data.google_project.common.id}"
  managed_zone = "${data.google_dns_managed_zone.chmsqrt2-domain.name}"

  name = "*.sitefe.live.truesparrow.${data.google_dns_managed_zone.chmsqrt2-domain.dns_name}"
  type = "A"
  ttl = "300"
  rrdatas = [ "${google_compute_global_address.live-loadbalancer-address.address}" ]
}

resource "google_dns_record_set" "live-adminfe-letsencrypt-challange" {
  project = "${data.google_project.common.id}"
  managed_zone = "${data.google_dns_managed_zone.chmsqrt2-domain.name}"

  name = "_acme-challenge.adminfe.live.truesparrow.${data.google_dns_managed_zone.chmsqrt2-domain.dns_name}"
  type = "TXT"
  ttl = "3600"
  rrdatas = [ "a1n5YdxIOTv_-kDPWCx01VD2IqRcpeXFAN9DRS471sk" ]
}

resource "google_dns_record_set" "live-sitefe-letsencrypt-challange" {
  project = "${data.google_project.common.id}"
  managed_zone = "${data.google_dns_managed_zone.chmsqrt2-domain.name}"

  name = "_acme-challenge.sitefe.live.truesparrow.${data.google_dns_managed_zone.chmsqrt2-domain.dns_name}"
  type = "TXT"
  ttl = "3600"
  rrdatas = [ "O5ZQB5H39h_Agr3DSF6153lMeusJmdkeadmZ5TeZIiw", "clbaHu_t3uU6olGwGZ5EBWh5zoGJrMInE6QbgLUydu4" ]
}

resource "google_compute_ssl_certificate" "live-loadbalancer-certificate" {
  project = "${google_project.live.id}"

  name = "chmsqrt2-truesparrow-live-loadbalancer-new-certificate"
  description = "Certificate for the live global loadbalancer"

  private_key = "${file("../certs-live/privkey.pem")}"
  certificate = "${file("../certs-live/fullchain.pem")}"
}
