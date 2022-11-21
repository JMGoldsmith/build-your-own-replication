# Building a single node in Vault using Docker.

This tutorial is built upon the expectation that you have completed your onboarding and gone through setting up a Vault node on your local desktop. 

## Tools you need

Docker desktop - Download from https://www.docker.com/products/docker-desktop/

Terraform - https://tfswitch.warrensbox.com/ - it is recommended to use TFSwitch or another env manager since you may need to replicate a customers Terraform version.

## The gitignore file

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

This prevents your terraform state, license, and various Vault related DBs to be uploaded to Github.

## Using Terraform

Now that you have created your `.gitignore` file, lets get building. In order to be able to quickly build and teardown your instances we will be using Terraform to manage the state of the node you are building. This will come in handy as you build out more environments to replicate certain customers issues. In future lessons, Terraform will also be used to manage Vault itself.

### Main.tf

Create a `main.tf` file in your the root of your folder. In your `main.tf` file there are 4 important resources that we will cover. They are:

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
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
    template = {
      source = "hashicorp/template"
    }
  }
  backend "local" {
    path = "tfstate/terraform.tfstate"
  }
}
```

This sets the Terraform version and where you store your state file. In this case, we will store it locally. It should be at the top of any Terraform project. This also sets up the [required provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs) for the docker provider.

We will then declare the provider:

```
provider "docker" {
  host = var.docker_host
}
```

This tells Terraform to use the Docker provider so that you can use Docker resource declarations in your Terraform file. You'll notice that the host is referencing `var.docker_host`. This is declared in the `vars.tf` file that we wil configure after setting up the `main.tf` file.

Next up we will create a custom Docker network. This will allow us to create a network for your container(s)

```
resource "docker_network" "repl_network" {
  name       = "repl-network"
  attachable = true
  ipam_config { subnet = "10.42.10.0/16" }
}
```

Next, we will declare the `docker_image`. This tells Docker where to get the image. We will keep it locally to save space. Notice the `${var.vault_version}` at the end of the `name` declaration.

```
resource "docker_image" "vault" {
  name         = "hashicorp/vault-enterprise:${var.vault_version}"
  keep_locally = true
}
```

The last piece in this file is the `docker_container`. There are multiple parts to this resource that are important. First we will look at the overall resource.

```
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
```

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

The next section, `capabilities`, sets the capabilities for the container. Here, we set it to `IPC_LOCK` to disable the mlock syscall.

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

The next section is your `healthcheck` section along with your port declarations and docker network settings. This allows you to configure how you can access the container inside and outside of container network as well as ensure the container is healthy.

Finally, we have the file upload section:

```
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
```

This section uploads the files to the container as well as creates volumes for your logs as well as for Raft.

### vars.tf

```
variable "docker_host" {
  default = "unix:///var/run/docker.sock"
}

variable "vault_license" {
  default = ""
}

variable "vault_version" {
  default = "1.11.1-ent"
}
```

### Config directory

#### vault.tftpl

This file, which resides in your config directory, is your Vault server configuration file. 

```
api_addr      = "http://10.42.10.20${node_id}:8200"
cluster_addr  = "http://10.42.10.20${node_id}:8201"
cluster_name  = "repl"
log_level     = "trace"
ui            = true
disable_mlock = true
license_path = "/vault/config/vault.hclic"

storage "raft" {
  path    = "/var/raft/"
  node_id = ${node_id}
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable = 1
}
```

This sets the internal API and Cluster addresses for the container. They are exposed from the declaration in the Terraform in the `ports` section. Feel free to create a name for yourself under the `cluster_name` setting. We are currently setting `tls_disable` to true as we will add certificates in a later tutorial.

#### vault.hclic

You can request a license from https://license.hashicorp.services. Please use your specific name and use the following modules:

```
      {
    "modules": [
        "multi-dc-scale",
        "governance-policy",
        "advanced-data-protection",
        "advanced-data-protection-key-management"
    ]
}
```

Save it as vault.hclic in the `config` directory.

### Init.sh

Use this to init your cluster. For this exercise, we will start out with the following lines:

```
#!/bin/bash

export VAULT_ADDR="http://127.0.0.1:8200"
terraform init
terraform apply -auto-approve
mkdir -p vault

vault operator init -key-shares=1 -key-threshold=1 > vault/vault.tmp
```

This will export your VAULT_ADDR address, run Terraform and then initialize Vault, storing the unseal and root keys in the `vault/vault.tmp` file.

### Teardown.sh

For this example, we will want to remove all resources and created DBs. Since this is a single node, we only want to remove that nodes data.

```
#!/bin/sh

terraform apply -destroy -auto-approve 

rm vault/vault.tmp
rm raft/raft-0/vault.db

rm raft/raft-0/raft/raft.db
```

### Interacting with your new cluster.

Currently you will need to set `export VAULT_ADDR="http://127.0.0.1:8200"` in your terminal as well. In later exercises we will have this set in to your shell.

Interacting with Vault can be done from the CLI, such as using `vault status`

### Accessing the container

Accessing the container itself can be done by running `docker exec -it vault-0 /bin/sh`. This will give you direct access to the Vault server for additional testing.

### Next lessons

Your first Integrated Storage cluster, managing Vault with Terraform, Consul backed storage, and cloud hosted instances for more advanced replication.