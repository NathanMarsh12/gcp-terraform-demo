terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
  }
  backend "gcs" {
    bucket = "dw-tf-state-nm"
    prefix = "terraform/state"

  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}



