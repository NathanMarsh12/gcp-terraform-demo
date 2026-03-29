resource "google_compute_instance" "vm_instance" {
  name                      = "terraform-instance"
  machine_type              = "e2-micro"
  tags                      = ["web", "dev"]
  allow_stopping_for_update = true

  labels = {
    environment = "dev"
    project     = "darkwolf-demo"
    managed_by  = "terraform"
  }

  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "nathanmarsh:${file("~/.ssh/id_rsa.pub")}"
  }

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
      nat_ip = google_compute_address.tf_instance_ip.address
    }
  }
}
resource "google_compute_address" "tf_instance_ip" {
  name = "instance-ip"
}
