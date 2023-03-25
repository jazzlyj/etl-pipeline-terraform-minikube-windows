resource "kubernetes_namespace_v1" "etl-dev" {
    metadata {
        name    = "etl-dev"
        labels  = {
          "app" = "etl"
        }
    }
}

resource "kubernetes_secret_v1" "etl-secret" {
      metadata {
        name               = "etl-secret"
        namespace          = kubernetes_namespace_v1.etl-dev.metadata.0.name
        labels             = {
          "sensitive"      = "true"
          "app"            = "etl"
        }
      }
      data = {
        "credentials.txt"  = file("${path.cwd}/credentials.txt")
      }
    }

resource "kubernetes_persistent_volume_v1" "etl-db-pv-volume" {
  metadata {
    name               = "etl-db-pv-volume"
    labels             = {
      "app"            = "etl"
    }
  }
  spec {
    capacity           = {
      storage          = "2Gi"
    }
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "manual"
    persistent_volume_source {
      local {
        path           = "/data/etl-db-pv-volume/"
      }
    }
    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key        = "kubernetes.io/hostname"
            operator   = "In"
            values     = [ "minikube" ]
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "etl-db-pv-claim" {
  metadata {
    name               = "etl-db-pv-claim"
    namespace          = kubernetes_namespace_v1.etl-dev.metadata.0.name
    labels             = {
      "app"            = "etl"
    }
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "manual"
    resources {
      requests         = {
        storage        = "1Gi"
      }
    }
  }
}



# module "postgresql" {
#   source        = "ballj/postgresql/kubernetes"
#   version       = "~> 1.2"
#   namespace     = "etl"
#   object_prefix = "db"
#   name          = "db"
#   image_name    = "bitnami/postgresql"
#   image_tag     = "14.7.0-7"
#   pvc_name      = "etl-db-pv-claim"
#   env_secret    = [
#     {
#       name   = "POSTGRES_USER"
#       secret = "etl-secret"
#       key    = "DBUser"
#     },
#     {
#       name   = "POSTGRES_PASSWORD"
#       secret = "etl-secret"
#       key    = "DBPassword"
#     },
#   ]
#   labels        = {
#     "app.kubernetes.io/part-of" = "etlapp"
#   }
# }
