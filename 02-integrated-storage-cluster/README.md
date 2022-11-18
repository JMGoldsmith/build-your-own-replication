# Creating a cluster from the Single Node tutorial.

note: Do not attempt this tutorial until you have completed the single-node tutorial. It builds off of that tutorial by making changes to various files.

## Main.tf
The `main.tf` file has a few changes to make in order to make this a cluster as opposed to a single node. 

### Changing the count

At this time, we will start with changing the count to 3 in order to get 3 nodes built by Terraform.

### Ports change

In the previous tutorial, you declared the ports individually. Unfortunately this will not work when you add more containers. In order to accommodate additional containers, you will need to adjust the `external` ports to increase their value with each new container. Here we use the `format()` function in Terraform to facilitate that. In a 3 node cluster it will create external ports 8200, 8210, and 8220.

```
  ports {
    internal = "8200"
    external = format("82%d0", count.index)
    protocol = "tcp"
  }
```

It is important to know these ports as to interact with that node through the Vault CLI you will need to export the `VAULT_ADDR="http://127.0.0.1:8200"` for the first node, `VAULT_ADDR="http://127.0.0.1:8210"` for the second node, and `VAULT_ADDR="http://127.0.0.1:8220"` for the third node.

### networks_advanced

The docker container has a reference to `networks_advanced` that will need an adjustment. As each container will need its own IP address, we can change the `ipv4_address` to take in to account the `count.index` for each unique container.

```
  networks_advanced {
    name         = "repl-network"
    ipv4_address = "10.42.10.20${count.index}"
  }
```

## Init.sh

Clustering your nodes includes the ability to join the nodes together. This tutorial assumes you have already gone through this procedure in your training.

First, we will need to check to ensure the `vault.tmp` file exists. This is important because it contains your unseal key and root token. As this is a replication environment we are only creating 1 unseal key. The `while` loop checks to see if the file exists. If it does not, it will wait until it does.

```
while : ; do
    [[ -f "vault/vault.tmp" ]] && break
    echo "Pausing until file exists."
    sleep 1
done
```

Next, we get the unseal key and set it to a value, then unseal the first node.

```
## Get key and unseal
KEY=$(grep "Unseal Key" vault/vault.tmp)
key_value=$(cut -d':' -f2 <<< $KEY) 
vault operator unseal $key_value
```

After that, we will get the root token and log in.

```
## Get token and log in
TOKEN=$(grep "Initial Root Token" vault/vault.tmp)
token_value=$(cut -d':' -f2 <<< $TOKEN)
echo $token_value
vault login $token_value
```

Next we will want to join the other two nodes to the cluster. This tutorial assumes a 3 node cluster but this script can be adjusted to allow for any number of nodes. See if you can refactor the code to take in any number of nodes!

```
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
### Make array based on number of nodes(get from query or input?)
### Take out existing leader node ID
### Join others based on remaining items in array.
```

By default, vault-0 will be the leader node at the end of the joining. You can also add items to enable services on this cluster, such as audit logs. You will want to change the `VAULT_ADDR` to speak to the leader node.

```
## Enable audit devices

export VAULT_ADDR="http://127.0.0.1:8200"
vault audit enable file file_path=/vault/logs/vault_audit.log
```
This tutorial does not utilize the `retry_join` stanza. We leave it up to you if you wish to enable this, but highly recommend you do so as an exercise.

## Teardown.sh

With each new node you add to the cluster you will need to change the teardown script. This takes in to account that it is a 3 node cluster and all items are hardcoded. This is another chance to refactor a script to allow it to delete all items in a directory recursively.

Your initial `teardown.sh` file should look like this:
 
```
terraform apply -destroy -auto-approve 

rm vault/vault.tmp
rm raft/raft-0/vault.db
rm raft/raft-1/vault.db
rm raft/raft-2/vault.db

rm raft/raft-0/raft/raft.db
rm raft/raft-1/raft/raft.db
rm raft/raft-2/raft/raft.db
```

## Run it!

Go ahead and build the cluster by running `./init.sh`! You will need to run the `./teardown.sh` file on your single node first, however.