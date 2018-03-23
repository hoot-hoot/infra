terraform {
  backend "gcs" {
    project = "chmsqrt2-truesparrow-common"
    bucket = "chmsqrt2-truesparrow-common-terraform-state"
    prefix = "state/boot"
  }
}
