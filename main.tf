resource "kubernetes_namespace" "etl" {
    metadata {
        name = "etl"
    }
}

resource "kubernetes_secret" "secret1" {

      metadata {
        name      = "pg-secret"
        namespace = kubernetes_namespace.etl.metadata.0.name
        labels = {
          "sensitive" = "true"
          "app"       = "etl"
        }
      }
      data = {
        "credentials.txt" = file("${path.cwd}/credentials.txt")
      }
    }

resource "kubernetes_persistent_volume_claim_v1" "etlpvc" {
  metadata {
    name = "etlpvc"
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    volume_name = "${kubernetes_persistent_volume_v1.etlpv.metadata.0.name}"
  }
  wait_until_bound = false
}

resource "kubernetes_persistent_volume_v1" "etlpv" {
  metadata {
    name = "etlpv"
  }
  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      local {
        path = "/var/lib/postgresql/data"
      }
    }
    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key = "kubernetes.io/hostname"
            operator = "In"
            values = [ "minikube" ]
          }
        }
      }
    }
  }
}


module "postgresql" {
  source        = "ballj/postgresql/kubernetes"
  version       = "~> 1.2"
  namespace     = "etl"
  object_prefix = "db"
  name          = "db"
  image_name    = "bitnami/postgresql"
  image_tag     = "14.7.0-7"
  pvc_name      = "etlpvc"
  env_secret    = [
    {
      name   = "POSTGRES_USER"
      secret = "pg-secret"
      key    = "DBUser"
    },
    {
      name   = "POSTGRES_PASSWORD"
      secret = "pg-secret"
      key    = "DBPassword"
    },
  ]
  labels        = {
    "app.kubernetes.io/part-of" = "etlapp"
  }
}
