provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"

  disable_on_destroy         = true
  disable_dependent_services = true
}

resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy         = true
  disable_dependent_services = true
}

resource "google_project_service" "serviceusage" {
  project = var.project_id
  service = "serviceusage.googleapis.com"

  disable_on_destroy = false
}

resource "google_compute_network" "genkart_vpc" {
  name                    = "genkart-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "genkart_subnet" {
  name                     = "genkart-subnet"
  ip_cidr_range            = "10.10.0.0/16"
  region                   = var.region
  network                  = google_compute_network.genkart_vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "genkart-pods"
    ip_cidr_range = "10.20.0.0/16"
  }
  secondary_ip_range {
    range_name    = "genkart-services"
    ip_cidr_range = "10.30.0.0/20"
  }

  depends_on = [google_project_service.compute]
}

resource "google_compute_router" "genkart_router" {
  name    = "genkart-router"
  network = google_compute_network.genkart_vpc.id
  region  = var.region

  depends_on = [google_project_service.compute]
}

resource "google_compute_router_nat" "genkart_nat" {
  name                                = "genkart-nat"
  router                              = google_compute_router.genkart_router.name
  region                              = var.region
  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  enable_endpoint_independent_mapping = true

  depends_on = [google_project_service.compute]
}

resource "google_container_cluster" "genkart_gke" {
  name       = "genkart-gke"
  location   = var.region
  network    = google_compute_network.genkart_vpc.id
  subnetwork = google_compute_subnetwork.genkart_subnet.id

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false

  # ---- START: MODIFICATION TO FIX SSD QUOTA ISSUE ----
  # This node_config applies to the temporary default node pool GKE creates
  # before removing it (due to remove_default_node_pool = true).
  # We force it to use pd-standard to avoid hitting SSD quotas.
  node_config {
    disk_type    = "pd-standard"
    disk_size_gb = 30 # Minimum is usually 10GB for COS, 30GB is a safe small size.
    # machine_type = "e2-small" # Optional: specify a small machine type too
  }
  # ---- END: MODIFICATION TO FIX SSD QUOTA ISSUE ----

  ip_allocation_policy {
    cluster_secondary_range_name  = "genkart-pods"
    services_secondary_range_name = "genkart-services"
  }

  enable_shielded_nodes = true
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All networks (customize for prod)"
    }
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  depends_on = [
    google_project_service.container,
    google_project_service.compute
  ]
}

resource "google_container_node_pool" "genkart_nodes" {
  name     = "genkart-node-pool"
  cluster  = google_container_cluster.genkart_gke.name
  location = var.region

  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard" # This node pool correctly uses pd-standard
    image_type   = "COS_CONTAINERD"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      env = var.env
    }

    tags = ["genkart-node"]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    # Optional for CMEK (uncomment if using KMS keys)
    # boot_disk_kms_key = "projects/${var.project_id}/locations/global/keyRings/your-keyring/cryptoKeys/your-key"
  }

  depends_on = [
    google_project_service.container,
    google_project_service.compute
  ]
}

resource "google_compute_firewall" "genkart-allow-internal" {
  name    = "genkart-allow-internal"
  network = google_compute_network.genkart_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["10.10.0.0/16", "10.20.0.0/16"] // Pod CIDR also included

  depends_on = [google_project_service.compute]
}

resource "google_compute_firewall" "genkart-allow-nodeports" {
  name    = "genkart-allow-nodeports"
  network = google_compute_network.genkart_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["genkart-node"]

  depends_on = [google_project_service.compute]
}

resource "google_compute_firewall" "genkart-allow-health-checks" {
  name    = "genkart-allow-health-checks"
  network = google_compute_network.genkart_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"] // Common ports for health checks, adjust if needed
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"] // Google Health Checker ranges

  depends_on = [google_project_service.compute]
}

resource "google_compute_address" "genkart_ingress_ip" {
  name   = "genkart-ingress-ip"
  region = var.region

  depends_on = [google_project_service.compute]
}

resource "google_compute_firewall" "genkart-allow-client" {
  name    = "genkart-allow-client"
  network = google_compute_network.genkart_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3005"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["genkart-node"]

  depends_on = [google_project_service.compute]
}

resource "google_compute_firewall" "genkart-allow-server" {
  name    = "genkart-allow-server"
  network = google_compute_network.genkart_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["5555"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["genkart-node"]

  depends_on = [google_project_service.compute]
}

resource "google_compute_firewall" "genkart-allow-argocd" {
  name    = "genkart-allow-argocd"
  network = google_compute_network.genkart_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["genkart-node"]

  depends_on = [google_project_service.compute]
}

resource "google_compute_firewall" "genkart-allow-sonarqube" {
  name    = "genkart-allow-sonarqube"
  network = google_compute_network.genkart_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["9000"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["genkart-node"]

  depends_on = [google_project_service.compute]
}

# Automatically install ArgoCD, Helm, and kubectl after GKE cluster creation
resource "null_resource" "post_gke_setup" {
  depends_on = [google_container_cluster.genkart_gke]

  provisioner "local-exec" {
    command     = <<EOT
      #!/bin/bash
      set -e
      echo "[INFO] Installing kubectl, helm, and ArgoCD after GKE cluster creation..."
      if ! command -v kubectl >/dev/null 2>&1; then
        echo "[INFO] Installing kubectl..."
        curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl && sudo mv kubectl /usr/local/bin/
      fi
      if ! command -v helm >/dev/null 2>&1; then
        echo "[INFO] Installing helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      fi
      if ! kubectl get ns argocd >/dev/null 2>&1; then
        echo "[INFO] Installing ArgoCD..."
        kubectl create namespace argocd
        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
      fi
      echo "[INFO] All tools installed and ArgoCD deployed."
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
