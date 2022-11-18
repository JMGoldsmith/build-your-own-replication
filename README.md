# build-your-own-replication

# The purpose

This repository includes guides on how to build your own replication environment. Uses Docker for local pieces, cloud specific for cloud providers. 

The included tutorials are:
Launching a single node with the Integrated Storage backend.
Launching a 3 node Integrated Storage Cluster

# Terraform

We are using Terraform to manage this cluster for various reasons. It will not only help you in quickly building your replication environment, but also help you adjust it to replicate a customers environment a lot faster. We will also be using Terraform to build various items within Vault itself, such as secrets engines, authentication methods and other items.

# Saving your work as terraform.

It is highly recommended to create a repository on github and save your work there. Being able to revert back to an early reference, keep customer environments as seperate branches, and maanging your state, are crucial here. 