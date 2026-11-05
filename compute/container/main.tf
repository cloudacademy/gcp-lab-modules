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

variable "image" {
  description = "The boot disk image for the container VM"
  type        = string
  default     = "debian-cloud/debian-12"
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

  validation {
    condition     = contains(["always", "onfailure", "never"], lower(var.restart_policy))
    error_message = "restart_policy must be Always, OnFailure, or Never."
  }
}

locals {
  image_arg   = "'${replace(var.container_image, "'", "'\\''")}'"
  restart_policy = lookup({
    always    = "always"
    onfailure = "on-failure"
    never     = "no"
  }, lower(var.restart_policy), "always")
  port_args = join(" ", [
    for port in var.container_ports : "--publish ${port.hostPort}:${port.containerPort}"
  ])
  env_args = join(" ", [
    for item in var.container_env : "--env '${replace(item.name, "'", "'\\''")}=${replace(item.value, "'", "'\\''")}'"
  ])
  container_startup_script = <<-EOT
    #!/usr/bin/env bash
    set -euxo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y docker.io
    systemctl enable --now docker
    docker pull ${local.image_arg}
    docker rm -f lab-container || true
    docker run --name lab-container --restart ${local.restart_policy} --detach ${local.port_args} ${local.env_args} ${local.image_arg}
  EOT
  host_ports = distinct([for port in var.container_ports : tostring(port.hostPort)])
}

resource "google_compute_firewall" "container_ports" {
  name    = "allow-container-vm-ports"
  network = var.network_id

  allow {
    protocol = "tcp"
    ports    = local.host_ports
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["container-vm"]
}

# Run the container on a standard Debian VM, without gce-container-declaration.
resource "google_compute_instance" "container_vm" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["container-vm"]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    network    = var.network_id
    subnetwork = var.subnetwork_id
    access_config {}
  }

  metadata_startup_script = local.container_startup_script

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
