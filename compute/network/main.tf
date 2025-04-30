# Variables

variable "region" {
    description = "The region where the instance will be created"
    type        = string
    default     = "us-central1"
}

variable "cidr_range" {
    description = "The CIDR range for the subnetwork"
    type        = string
}

# Network
resource "google_compute_network" "vm_network" {
  name                    = "vm-network"
  auto_create_subnetworks = false
}

# Subnetwork
resource "google_compute_subnetwork" "vm_subnet" {
  name          = "vm-subnet"
  network       = google_compute_network.vm_network.id
  region        = var.region
  ip_cidr_range = var.cidr_range
}

# Firewall rule to allow SSH access
resource "google_compute_firewall" "vm_network_allow_ssh" {
  name    = "vm-network-allow-ssh"
  network = google_compute_network.vm_network.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Outputs

output "network_id" {
    description = "The ID of the VM network"
    value       = google_compute_network.vm_network.id
}

output "subnet_id" {
    description = "The ID of the VM subnetwork"
    value       = google_compute_subnetwork.vm_subnet.id
}