output "gke_cluster_name" {
  value       = google_container_cluster.genkart_gke.name
  description = "The name of the GKE cluster."
}

output "gke_cluster_endpoint" {
  value       = google_container_cluster.genkart_gke.endpoint
  description = "The endpoint of the GKE cluster."
}

output "gke_node_pool_name" {
  value       = google_container_node_pool.genkart_nodes.name
  description = "The name of the GKE node pool."
}

output "network_name" {
  value       = google_compute_network.genkart_vpc.name
  description = "The name of the VPC network."
}

output "subnet_name" {
  value       = google_compute_subnetwork.genkart_subnet.name
  description = "The name of the subnet."
}
