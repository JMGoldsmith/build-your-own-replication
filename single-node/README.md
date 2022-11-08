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


### vars.tf
### Init.sh

Use this to init your cluster. 

### Config directory

vault.tftpl
vault.hclic

