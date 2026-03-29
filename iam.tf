resource "google_service_account" "vm_sa" {
  account_id   = "dw-demo-vm-sa"
  display_name = "DW Demo Service Account"
  description  = "Least privilege service account for the Terraform demo VM"
  depends_on   = [google_project_service.iam]
}

resource "google_project_iam_member" "project" {
  project = var.project
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}