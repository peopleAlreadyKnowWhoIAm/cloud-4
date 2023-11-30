terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.7.0"
    }
  }
  backend "gcs" {
    prefix = "terraform/state"
    bucket = "lab4-406621-bucket-tfstate"
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_project_service" "iam" {
  project = var.project
  service = "iam.googleapis.com"

  disable_dependent_services = true
}
resource "google_project_service" "compute_engine" {
  project = var.project
  service = "compute.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "crm" {
  project = var.project
  service = "cloudresourcemanager.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "artifactregistry" {
  project = var.project
  service = "artifactregistry.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "run" {
  project = var.project
  service = "run.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "cb" {
  project = var.project
  service = "cloudbuild.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "sn" {
  project = var.project
  service = "servicenetworking.googleapis.com"
  disable_dependent_services = true
}
resource "google_project_service" "sqladmin" {
  project = var.project
  service = "sqladmin.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "buckets" {
  project = var.project
  service = "storage.googleapis.com" 
}

resource "google_storage_bucket" "default" {
  name          = "${var.project}-bucket-tfstate"
  force_destroy = false
  location      = "EU"
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
  depends_on = [
    google_project_service.buckets
  ]
}

output "bucket_name" {
  value = google_storage_bucket.default.name
}
resource "google_compute_network" "vpc_network" {
  depends_on = [ google_project_service.compute_engine ]
  name = "sql-network"
}

resource "google_compute_subnetwork" "project_sn" {
  name          = "project-sn"
  network       = google_compute_network.vpc_network.id
  ip_cidr_range = "10.0.0.0/16"
}

resource "google_service_account" "cloudbuild_service_account" {
  depends_on = [ google_project_service.iam ]
  account_id = "cloud-sa"
}

resource "google_project_iam_member" "act_as" {
  project = var.project
  role    = "roles/editor"
  member  = google_service_account.cloudbuild_service_account.member
}

resource "google_cloudbuild_trigger" "bt_server" {
  name = "bt-server"
  github {
    owner = "peopleAlreadyKnowWhoIAm"
    name  = "db-5"
    push {
      branch = "clouds"
    }
  }
  depends_on = [ google_project_iam_member.act_as , google_project_service.cb]
  service_account = google_service_account.cloudbuild_service_account.id
  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "--no-cache",
        "-t",
        "$_AR_HOSTNAME/$PROJECT_ID/cloud-run-source-deploy/$REPO_NAME/$_SERVICE_NAME:$COMMIT_SHA",
        ".",
        "-f",
        "Dockerfile"
      ]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "$_AR_HOSTNAME/$PROJECT_ID/cloud-run-source-deploy/$REPO_NAME/$_SERVICE_NAME:$COMMIT_SHA"
      ]
    }
    step {
      name = "gcr.io/google.com/cloudsdktool/cloud-sdk:slim"
      args = [
        "run",
        "services",
        "update",
        "$_SERVICE_NAME",
        "--platform=managed",
        "--image=$_AR_HOSTNAME/$PROJECT_ID/cloud-run-source-deploy/$REPO_NAME/$_SERVICE_NAME:$COMMIT_SHA",
        "--labels=managed-by=gcp-cloud-build-deploy-cloud-run,commit-sha=$COMMIT_SHA,gcb-build-id=$BUILD_ID",
        "--region=$_DEPLOY_REGION",
        "--quiet",
      ]
      entrypoint = "gcloud"
    }
    images = ["$_AR_HOSTNAME/$PROJECT_ID/cloud-run-source-deploy/$REPO_NAME/$_SERVICE_NAME:$COMMIT_SHA"]
    substitutions = {
      _SERVICE_NAME  = var.server_service,
      _DEPLOY_REGION = var.region,
      _AR_HOSTNAME   = format("%s-docker.pkg.dev", var.region)
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }

  }
}


resource "google_cloudbuild_trigger" "bt_loadder" {
  name = "bt-loader"
  github {
    owner = "peopleAlreadyKnowWhoIAm"
    name  = "cloudd-2-loader"
    push {
      branch = "master"
    }
  }
  depends_on = [ google_project_iam_member.act_as , google_project_service.cb]
  service_account = google_service_account.cloudbuild_service_account.id
  build {
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "--no-cache",
        "-t",
        "$_AR_HOSTNAME/$PROJECT_ID/cloud-run-source-deploy/$REPO_NAME/$_SERVICE_NAME:$COMMIT_SHA",
        ".",
        "-f",
        "Dockerfile"
      ]
    }
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "$_AR_HOSTNAME/$PROJECT_ID/cloud-run-source-deploy/$REPO_NAME/$_SERVICE_NAME:$COMMIT_SHA"
      ]
    }
    step {
      name = "gcr.io/google.com/cloudsdktool/cloud-sdk:slim"
      args = [
        "run",
        "services",
        "update",
        "$_SERVICE_NAME",
        "--platform=managed",
        "--image=$_AR_HOSTNAME/$PROJECT_ID/cloud-run-source-deploy/$REPO_NAME/$_SERVICE_NAME:$COMMIT_SHA",
        "--labels=managed-by=gcp-cloud-build-deploy-cloud-run,commit-sha=$COMMIT_SHA,gcb-build-id=$BUILD_ID",
        "--region=$_DEPLOY_REGION",
        "--quiet",
      ]
      entrypoint = "gcloud"
    }
    images = ["$_AR_HOSTNAME/$PROJECT_ID/cloud-run-source-deploy/$REPO_NAME/$_SERVICE_NAME:$COMMIT_SHA"]
    substitutions = {
      _SERVICE_NAME  = var.loader_service,
      _DEPLOY_REGION = var.region,
      _AR_HOSTNAME   = format("%s-docker.pkg.dev", var.region)
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}

resource "google_artifact_registry_repository" "image_repo" {
  depends_on = [ google_project_service.artifactregistry ]
  repository_id = "cloud-run-source-deploy"
  format        = "DOCKER"
  location      = var.region
}
resource "google_artifact_registry_repository_iam_member" "registry_access" {
  repository = google_artifact_registry_repository.image_repo.repository_id
  member = google_service_account.cloudbuild_service_account.member
  role = "roles/artifactregistry.createOnPushWriter"
}

resource "google_sql_database" "db" {
  name     = "itunes"
  instance = google_sql_database_instance.db_instance.id
}
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}
resource "google_service_networking_connection" "db_connection" {
  depends_on = [ google_project_service.sn , google_project_service.sqladmin]
  network = google_compute_network.vpc_network.id
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_sql_database_instance" "db_instance" {
  name = "database"
  region           = var.region
  database_version = "MYSQL_8_0"
  root_password    = var.sql_root_psw
  depends_on = [ google_service_networking_connection.db_connection ]
  deletion_protection = false
  settings {
    edition = "ENTERPRISE"
    tier            = "db-f1-micro"
    disk_type       = "PD_HDD"
    disk_size       = 10
    disk_autoresize = false
    ip_configuration {
      ipv4_enabled = false
      private_network = google_compute_network.vpc_network.id
    }
  }
}

resource "google_sql_user" "client" {
  name = "client"
  password = var.sql_client_psw
  host = "%"
  instance = google_sql_database_instance.db_instance.id
  type = "BUILT_IN"
}

resource "google_cloud_run_v2_service" "server" {
  depends_on = [ google_project_service.run ]
  name         = var.server_service
  location     = var.region
  ingress      = "INGRESS_TRAFFIC_ALL"
  launch_stage = "BETA"
  template {
    scaling {
      min_instance_count = 0
      max_instance_count = 50
    }
    containers {
      ports {
        container_port = 8080
      }

      image = "us-docker.pkg.dev/cloudrun/container/hello"
      env {
        name  = "DATASOURCE_PASSWORD"
        value = google_sql_user.client.password
      }
      env {
        name  = "DATASOURCE_URL"
        value = format("%s:3306/%s", google_sql_database_instance.db_instance.private_ip_address, google_sql_database.db.name)
      }
      env {
        name  = "DATASOURCE_USER"
        value = google_sql_user.client.name
      }
    }
    
    vpc_access {
      network_interfaces {
        network    = google_compute_network.vpc_network.id
        subnetwork = google_compute_subnetwork.project_sn.id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "server_access" {
  name = google_cloud_run_v2_service.server.name
  member = "allUsers"
  role = "roles/run.invoker"
}
resource "google_cloud_run_v2_service" "loader" {
  depends_on = [ google_project_service.run ]
  name     = var.loader_service
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  template {
    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
    containers {
      ports {
        container_port = 8089
      }

      image = "us-docker.pkg.dev/cloudrun/container/hello"

    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "loader_access" {
  name = google_cloud_run_v2_service.loader.name
  member = "allUsers"
  role = "roles/run.invoker"
}