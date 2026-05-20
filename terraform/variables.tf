# variables.tf
# Terraform variables for GKE cluster deployment

variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "The Google Cloud region for resources"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "The zone to deploy resources"
  default     = "us-central1-a"
}

variable "node_count" {
  description = "Initial number of nodes in the node pool"
  type        = number
  default     = 1
  validation {
    condition     = var.node_count >= 1 && var.node_count <= 3
    error_message = "Node count must be between 1 and 3 to stay within quota limits."
  }
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium" # 2 vCPUs, 4GB RAM - good balance of cost and performance
  validation {
    condition = contains([
      "e2-micro", "e2-small", "e2-medium", "e2-standard-2", "e2-standard-4",
      "n1-standard-1", "n1-standard-2", "n1-standard-4",
      "n2-standard-2", "n2-standard-4"
    ], var.node_machine_type)
    error_message = "Node machine type must be a valid Google Cloud machine type."
  }
}

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# Optional: Add these if you want to make disk configuration customizable
variable "node_disk_size_gb" {
  description = "Disk size for each node in GB"
  type        = number
  default     = 50
  validation {
    condition     = var.node_disk_size_gb >= 10 && var.node_disk_size_gb <= 100
    error_message = "Node disk size must be between 50GB and 100GB to stay within quota limits."
  }
}

variable "node_disk_type" {
  description = "Disk type for nodes (pd-standard, pd-balanced, pd-ssd)"
  type        = string
  default     = "pd-standard"
  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd"], var.node_disk_type)
    error_message = "Disk type must be one of: pd-standard, pd-balanced, pd-ssd."
  }
}