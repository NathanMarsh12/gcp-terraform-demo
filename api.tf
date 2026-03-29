resource "google_project_service" "compute" {
  project            = var.project
  service            = "compute.googleapis.com"
  disable_on_destroy = false

}

resource "google_project_service" "storage" {
  project            = var.project
  service            = "storage.googleapis.com"
  disable_on_destroy = false


}

resource "google_project_service" "iam" {
  project            = var.project
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}


