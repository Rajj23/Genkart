# Genkart GKE Terraform Deployment

This Terraform configuration provisions a production-ready Google Kubernetes Engine (GKE) cluster and supporting resources for the Genkart project.

## Resources Created
- Custom VPC and subnet (named `genkart-vpc` and `genkart-subnet`)
- GKE cluster (`genkart-gke`) with a dedicated node pool (`genkart-node-pool`)
- All resources are tagged and named for easy identification (no use of `default`)

## Usage

### 1. Prerequisites
- [Terraform](https://www.terraform.io/downloads.html) >= 1.3.0
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- A GCP project with billing enabled
- Enable the following APIs:
  - Kubernetes Engine API
  - Compute Engine API

### 2. Configure Authentication
Login and set your project:
```zsh
gcloud auth login
gcloud config set project <YOUR_PROJECT_ID>
```

### 3. Initialize Terraform
```zsh
cd terraform
terraform init
```

### 4. Set Variables
Create a `terraform.tfvars` file or pass variables via CLI:
```hcl
project_id    = "your-gcp-project-id"
region        = "us-central1"
node_count    = 2
node_machine_type = "e2-medium"
env           = "dev"
```

### 5. Apply
```zsh
terraform apply
```

### 6. Configure kubectl
After apply, get credentials:
```zsh
gcloud container clusters get-credentials genkart-gke --region us-central1
```

You can now deploy your Helm chart or Kubernetes manifests to the new cluster.

---

## Notes
- All resource names are prefixed with `genkart-` for easy management.
- For production, consider using private nodes, node auto-scaling, and workload identity.
- This setup does not provision a database; use MongoDB Atlas or a managed GCP database.

---
