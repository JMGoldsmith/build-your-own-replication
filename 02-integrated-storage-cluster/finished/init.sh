#!/bin/bash
export VAULT_ADDR="http://127.0.0.1:8200"
terraform init
terraform apply -auto-approve
mkdir -p vault
vault operator init -key-shares=1 -key-threshold=1 > vault/vault.tmp

while : ; do
    [[ -f "vault/vault.tmp" ]] && break
    echo "Pausing until file exists."
    sleep 1
done

## Get key and unseal
KEY=$(grep "Unseal Key" vault/vault.tmp)
key_value=$(cut -d':' -f2 <<< $KEY) 
vault operator unseal $key_value


## Get token and log in
TOKEN=$(grep "Initial Root Token" vault/vault.tmp)
token_value=$(cut -d':' -f2 <<< $TOKEN)
echo $token_value
vault login $token_value

## join other nodes.

export VAULT_ADDR="http://127.0.0.1:8210"
vault operator raft join "http://10.42.10.200:8200"
sleep 10
vault operator unseal $key_value

export VAULT_ADDR="http://127.0.0.1:8220"
vault operator raft join "http://10.42.10.200:8200"
sleep 10
vault operator unseal $key_value

sleep 10
vault operator raft list-peers
