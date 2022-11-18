#!/bin/sh

terraform apply -destroy -auto-approve 

rm vault/vault.tmp
rm raft/raft-0/vault.db
rm raft/raft-1/vault.db
rm raft/raft-2/vault.db

rm raft/raft-0/raft/raft.db
rm raft/raft-1/raft/raft.db
rm raft/raft-2/raft/raft.db

