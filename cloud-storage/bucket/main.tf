variable "name_prefix" {
  description = "The prefix for the bucket name."
  type        = string
  default     = "calabs-bucket"
}

variable "bucket_name" {
  description = "The name of the bucket. If not provided, it will be generated."
  type        = string
  default     = null
}

variable "location" {
  description = "The location for the bucket. Defaults to 'US'."
  type        = string
  default     = "US"
}

variable "versioning_enabled" {
  description = "Whether versioning is enabled for the bucket."
  type        = bool
  default     = false
}

resource "google_storage_bucket" "bucket" {
  name          = var.bucket_name != null ? var.bucket_name : "${var.name_prefix}-${timestamp()}"
  location      = var.location
  storage_class = "STANDARD"

  versioning {
    enabled = var.versioning_enabled
  }
}

resource "google_storage_bucket_access_control" "bucket_acl" {
  bucket = google_storage_bucket.bucket.name
  role   = "WRITER"
  entity = "allUsers"
}

output "lab_bucket_name" {
  description = "The name of the created bucket."
  value       = google_storage_bucket.bucket.name
}