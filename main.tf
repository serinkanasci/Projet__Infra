provider "google" {
  project     = var.project
  region      = var.location
  credentials = file("./friendly-magnet-321013-540f9f694655.json")
}

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.13.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Pulls the image
resource "docker_image" "nginx" {
  name = "serinkan/nginx_sample"
}

# Create a container
resource "docker_container" "container" {
  image = "${docker_image.nginx.name}"
  name  = "nginx-terraform"
}

resource "google_container_cluster" "default" {
  name        = var.name
  project     = var.project
  description = "Project GKE Cluster"
  location    = var.location

  remove_default_node_pool = true
  initial_node_count       = var.initial_node_count

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "default" {
  name       = "${var.name}-node-pool"
  project    = var.project
  location   = var.location
  cluster    = google_container_cluster.default.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = var.machine_type

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}


resource "kubernetes_deployment" "nginxDeploy" {
  metadata {
    name = "terraform-nginx"
    labels = {
      test = "terraformNginx"
    }
  }
  spec {
    replicas = 3

    selector {
      match_labels = {
        test = "terraformNginx"
      }
    }

    template {
      metadata {
        labels = {
          test = "terraformNginx"
        }
      }

      spec {
        container {
          image = docker_image.nginx.name
          name  = "nginx"

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}


resource "kubernetes_deployment" "grafanaDeploy" {
  metadata {
    name = "terraform-grafana"
    labels = {
      test = "terraformGrafana"
    }
  }
  spec {
    replicas = 3

    selector {
      match_labels = {
        test = "terraformGrafana"
      }
    }

    template {
      metadata {
        labels = {
          test = "terraformGrafana"
        }
      }

      spec {
        container {
          image = "grafana:latest"
          name  = "grafana"

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}
resource "google_cloud_scheduler_job" "job" {
  name             = "curl-job"
  description      = "curl every day at seven"
  schedule         = "0 7 * * *"
  attempt_deadline = "320s"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "GET"
      uri = "${google_cloud_run_service.report-generator-service.status[0].url}/v1/weather/hello1"    
      oidc_token {
      service_account_email = "terraform@charged-library-280615.iam.gserviceaccount.com"
    }
  }
}
