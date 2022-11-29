terraform {
  required_version = ">= 0.13"
  required_providers {
    docker = {
      source = "terraform-providers/docker"
    }
    template = {
      source = "hashicorp/template"
    }
  }
  backend "local" {
    path = "tfstate/terraform.tfstate"
  }
}

provider "docker" {
  host = var.docker_host
}

# -----------------------------------------------------------------------
# Custom network
# -----------------------------------------------------------------------
resource "docker_network" "raft_network" {
  name       = "raft-network"
  attachable = true
  ipam_config { subnet = var.network_cidr != "" ? var.network_cidr : "10.42.10.0/16" } 
}


# -----------------------------------------------------------------------
# Vault data and resources
# -----------------------------------------------------------------------

resource "docker_image" "vault" {
  name         = "hashicorp/vault-enterprise:${var.vault_version}"
  keep_locally = true
}

resource "docker_container" "vault" {
  count    = 3
  name     = "vault-${count.index}"
  image    = docker_image.vault.latest
  env      = ["SKIP_CHOWN", "VAULT_ADDR=http://127.0.0.1:8200", "VAULT_LICENSE=${var.vault_license}"]
  command  = ["vault", "server", "-log-level=trace", "-config=/vault/config"]
  hostname = "vault-${count.index}"
  must_run = true

  capabilities {
    add = ["IPC_LOCK"]
  }

  healthcheck {
    test         = ["CMD", "vault", "status"]
    interval     = "10s"
    timeout      = "15s"
    start_period = "10s"
    retries      = 15
  }

  ports {
    internal = "8200"
    external = format("82%d0", count.index)
    protocol = "tcp"
  }

  networks_advanced {
    name         = "raft-network"
    ipv4_address = "10.42.10.20${count.index}"
  }

  upload {
    content = templatefile("${path.cwd}/config/vault.tftpl", { node_id = count.index })
    file    = "/vault/config/server.hcl"
  }

  upload {
    content = templatefile("${path.cwd}/config/vault.hclic", {})
    file    = "/vault/config/vault.hclic"
  }

  volumes {
    host_path      = "${path.cwd}/raft/raft-${count.index}"
    container_path = "/var/raft"
  }

  volumes {
    host_path      = "${path.cwd}/logs/vault-audit-log-${count.index}"
    container_path = "/vault/logs"
  }
}
