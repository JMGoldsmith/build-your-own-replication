#!/bin/bash

export VAULT_ADDR="http://127.0.0.1:8200"

terraform init
terraform apply -auto-approve
mkdir -p vault
vault operator init -key-shares=1 -key-threshold=1 > vault/vault.tmp