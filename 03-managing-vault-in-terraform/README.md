# Managing Vault through Terraform.

## Organizing your TF

Normally you would keep your Terraform in a tidy directory with proper structure. In order to maintain state, I would recommend putting each secret, auth, and other resources in separate folders for testing.

## The provider

### Pinning versions

When 

### Documentation

https://registry.terraform.io/providers/hashicorp/vault/latest/docs

When using this against local clusters, being logged in with a root token is enough to give Terraform the rights to perform Vault actions. If using a cloud service, please see https://registry.terraform.io/providers/hashicorp/vault/latest/docs#vault-authentication-configuration-options

To do - enable secret or generic mount backend resource block

## Enabling secrets

You can either use the `vault_mount` or specific resource for the engine you wish to enable. The `vault_mount` does have the option to create a generic mount, however, which can be helpful in some cases. You can also update various configuration options using the `vault_generic_endpoint` resource when those [configuration options do not exist in the Terraform provider](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/generic_endpoint).



## Audit logging 

Audit logging can be enabled through Terraform as well. In our Docker replication environment you can also set it to enable every time, but it may help with system resources to enable it only when you need to. In order to keep the container replication environment as immutable as possible, we can use the following:

```
resource "vault_audit" "test" {
  type = "file"

  options = {
    file_path = "/vault/logs"
  }
}
```

## Policies

### Regular

### EGP

## Namespaces


## Tuning

