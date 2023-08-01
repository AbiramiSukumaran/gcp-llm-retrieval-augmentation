# Create a Artifact Registry repository to host the docker image

resource "google_artifact_registry_repository" "api" {
  location      = var.region
  repository_id = "retrieval-augmentation-api"
  description   = "API for Retrieval Augmentation example"
  format        = "DOCKER"
}

# Create a Cloud Build Trigger pointing to the GitHub Repo

resource "google_service_account" "cloudbuild" {
  account_id   = "retreival-aug-cloudbuild"
  display_name = "Service Account for the Retrieval Augmentation API Cloud Build"
}

resource "google_project_iam_member" "cloudbuild_cloudrun_binding" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_cloudbuild_trigger" "githun_repo" {
  location = var.region
  name     = "retrieve-augment-api"
  filename = "cloudbuild.yml"

  service_account = google_service_account.cloudbuild.id

  github {
    owner = "danielfrg"
    name  = "gcp-llm-retrieval-augmentation"
    push {
      branch = "^main$"
    }
  }

  include_build_logs = "INCLUDE_BUILD_LOGS_WITH_STATUS"
}

# Create the Cloud Run Service

resource "google_service_account" "cloudrun_api" {
  account_id   = "retreival-aug-cloudrun-api"
  display_name = "Service Account for the Retrieval Augmentation Cloud Run API"
}

resource "google_project_iam_member" "cloudrun_aiplatform_binding" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.cloudrun_api.email}"
}

resource "google_cloud_run_v2_service" "api" {
  name     = "retreival-augmentation-api"
  location = var.region

  template {
    service_account = google_service_account.cloudrun_api.email

    containers {
      image = "us-central1-docker.pkg.dev/llmops-demos-frg/retrieval-augmentation-api/api"
      resources {
        limits = {
          memory = "3Gi"
          cpu    = "2"
        }
      }
    }
  }
}

# Allow unauthenticated (allUsers) to invoke the Cloud Run Service

resource "google_cloud_run_service_iam_binding" "unauthenticated" {
  location = google_cloud_run_v2_service.api.location
  service  = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}
