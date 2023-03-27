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
      binary_data = {
        "DBHost"     = ""
        "DBUser"     = ""
        "DBPassword" = ""
        "DBSchema"   = ""
        "DBName"     = ""
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
    # Need this or K8s (minikube) will try to dynamically create a pv for the pvc
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
    # Need this or K8s (minikube) will try to dynamically create a pv for the pvc
    storage_class_name = "manual"
    resources {
      requests         = {
        storage        = "1Gi"
      }
    }
  }
}


resource "kubernetes_pod_v1" "postgres" {
  metadata {
    name       = "etl-db"
    namespace  = kubernetes_namespace_v1.etl-dev.metadata.0.name
    labels     = {
      "app"    = "etl"
    }
  }
  spec {
    container {
      image = "postgres"
      name  = "db"
      env {
        name  = "PGDATA"
        value = "/var/lib/postgresql/data"
      }
      env {
        name  = "POSTGRES_DB"
        value_from {
          secret_key_ref {
            name = "etl-secret"
            key = "DBName"
          }
        }
      }
      env {
        name  = "POSTGRES_USER"
        value_from {
          secret_key_ref {
            name = "etl-secret"
            key  = "DBUser"
          }
        }
      }  
      env {
        name  = "POSTGRES_PASSWORD"
        value_from {
          secret_key_ref {
            name = "etl-secret"
            key  = "DBPassword"
          }
        }
      }  
      port {
        container_port = 5432
      }
      # lifecycle {
      #   post_start {
      #     exec {
      #       command = ["/bin/sh","-c","sleep 20 && PGPASSWORD=$POSTGRES_PASSWORD psql -w -d $POSTGRES_DB -U $POSTGRES_USER -c 'CREATE TABLE IF NOT EXISTS gendercounts (id SERIAL PRIMARY KEY,gender TEXT, count INT4);'"]
      #     }
      #   }
      # }
    }
    volume {
      name = "etl-db-data"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim_v1.etl-db-pv-claim.metadata.0.name
      }
    }
  }
}

resource "kubernetes_service" "db-service" {
  metadata {
    name       = "etl-db-service"
    namespace  = kubernetes_namespace_v1.etl-dev.metadata.0.name
    labels     = {
      "app"    = "etl"
    }
  }
  spec {
    selector = {
      app    = "${kubernetes_pod_v1.postgres.metadata.0.labels.app}"
    }
    session_affinity = "ClientIP"
    port {
      port        = 5432
      target_port = 5432
    }
  }
}