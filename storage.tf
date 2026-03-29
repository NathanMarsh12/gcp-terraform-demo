resource "google_storage_bucket" "app_data" {
  name          = "tf-app-data-dw-demo"
  location      = "US"
  force_destroy = false

  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  lifecycle_rule {
    condition {
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }


  depends_on = [google_project_service.storage]

  labels = {
    environment = "dev"
    project     = "darkwolf-demo"
    managed_by  = "terraform"
  }
}
