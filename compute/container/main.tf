# Variables
variable "instance_name" {
  description = "Name of the compute instance"
  type        = string
}

variable "machine_type" {
  description = "The machine type to use for the instance"
  type        = string
}

variable "zone" {
  description = "The zone where the instance will be created"
  type        = string
}

variable "network_id" {
  description = "The ID of the network to attach the instance to"
  type        = string
}

variable "subnetwork_id" {
  description = "The ID of the subnetwork to attach the instance to"
  type        = string
}

variable "service_account_email" {
  description = "The email of the service account to attach to the instance"
  type        = string
}

variable "container_image" {
  description = "Container image to deploy (e.g., gcr.io/google-samples/hello-app:2.0)"
  type        = string
  default     = "gcr.io/google-samples/hello-app:2.0"
}

variable "container_ports" {
  description = "Ports to expose from the container"
  type        = list(object({
    containerPort = number
    hostPort      = number
  }))
  default     = [
    {
      containerPort = 8080
      hostPort      = 8080
    }
  ]
}

variable "container_env" {
  description = "Environment variables for the container"
  type        = list(object({
    name  = string
    value = string
  }))
  default     = []
}

variable "restart_policy" {
  description = "Restart policy for the container (Always, OnFailure, Never)"
  type        = string
  default     = "Always"
}

# Use the Google container VM module to generate container metadata
module "gce-container" {
  source  = "terraform-google-modules/container-vm/google"
  version = "~> 3.0"
  
  container = {
    image = var.container_image
    ports = var.container_ports
    env   = var.container_env
  }
  
  restart_policy = var.restart_policy
}

# Create the VM instance with container
resource "google_compute_instance" "container_vm" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = module.gce-container.source_image
    }
  }

  network_interface {
    network    = var.network_id
    subnetwork = var.subnetwork_id
    access_config {}
  }

  metadata = {
    gce-container-declaration = module.gce-container.metadata_value
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"
  }

  labels = {
    container-vm = module.gce-container.vm_container_label
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# Outputs
output "instance_id" {
  description = "The ID of the container instance"
  value       = google_compute_instance.container_vm.id
}

output "instance_name" {
  description = "The name of the container instance"
  value       = google_compute_instance.container_vm.name
}

output "external_ip" {
  description = "The external IP address of the instance"
  value       = google_compute_instance.container_vm.network_interface[0].access_config[0].nat_ip
}