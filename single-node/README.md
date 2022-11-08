# Building a single node in Vault using Docker.

### Tools you need

Docker desktop
Terraform

### gitignore

The very first thing you will want to do in this and every replication repo you build is to add a `.gitignore` file to the root of the directory. This is to ensure that you do not upload any files to github that should not be there. The most important is your license. Since you most likely have all of the enterprise features tied to your license, this could allow someone to use Vault enterprise without paying. 

My current, and suggested, `.gitignore` file includes the following items:

```
tfstate/*
config/vault.hclic
.terraform.lock.hcl
vault/*
raft/
logs/
.terraform
```

This prevents your terraform state, license, and DBs to be uploaded to Github.

### Using Terraform

Now that you have created your `.gitignore` file, lets get building. In order to be able to quickly build and teardown your instances we will be using Terraform to manage the state of the node you are building. This will come in handy as you build out more environments to replicate certain customers issues. In future lessons, Terraform will also be used to manage Vault itself.

### Main.tf

In your main.tf file that will go in your root directory, there are 4 important resources that we will cover. They are:

```
providers
docker_network
docker_image
docker_container
```

At the top of your file please place the following:

```
terraform {
  required_version = ">= 0.13"
  backend "local" {
    path = "tfstate/terraform.tfstate"
  }
}
```

This sets the Terraform version and where you store your state file. In this case, we will store it locally. 

We will then declare the provider:

```
provider "docker" {
  host = var.docker_host
}
```

This tells Terraform to use the Docker provider so that you can use Docker resource declarations in your Terraform file.

Next up we will create a custom Docker network. This will allow us to create a network for your container(s)

```
resource "docker_network" "repl_network" {
  name       = "repl-network"
  attachable = true
  ipam_config { subnet = "10.42.10.0/16" }
}
```

Next, we will declare the `docker_image`. This tells Docker where to get the image. We will keep it locally to save space.

```
resource "docker_image" "vault" {
  name         = "hashicorp/vault-enterprise:${var.vault_version}"
  keep_locally = true
}
```

The last piece in this file is the `docker_container`. There are multiple parts to this resource that are important. First we will look at the overall resource.

resource "docker_container" "vault" {
  count    = 1
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
    name         = "repl-network"
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

A lot of the pieces in this resource are configured so that we can iterate on the file later to make this in to a cluster. At this time, we only want a single node, however.

The first section is the main section of the resource:

```
  count    = 1
  name     = "vault-${count.index}"
  image    = docker_image.vault.latest
  env      = ["SKIP_CHOWN", "VAULT_ADDR=http://127.0.0.1:8200", "VAULT_LICENSE=${var.vault_license}"]
  command  = ["vault", "server", "-log-level=trace", "-config=/vault/config"]
  hostname = "vault-${count.index}"
  must_run = true
```

The count tells us that we want a single container built. The `name` is to name the container properly. Notice how we set the name to include a numerical value from the count index. This will always start at 0. The `image` is a reference to the `docker_image` resource we declared earlier. The `env` section sets the environment variables in the container. The `command` section runs the command to start Vault. The `hostname` is the same as the name. `must_run` ensures the container will run when loaded.

```
 capabilities {
    add = ["IPC_LOCK"]
  }
```

The next section, `capabilities`, sets the capabilities for the container. Here, we set it to `IPC_LOCK`.

```
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
    name         = "repl-network"
    ipv4_address = "10.42.10.20${count.index}"
  }
```

The next section is your `healthcheck` section along with your port declarations and docker network settings. This allows you to configure how you can access the container inside and outside of container network. 




### vars.tf
### Init.sh

Use this to init your cluster. 

### Config directory

vault.tftpl
vault.hclic

