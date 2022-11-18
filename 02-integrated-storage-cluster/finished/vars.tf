variable "docker_host" {
  default = "unix:///var/run/docker.sock"
}

variable "vault_license" {
  default = ""
}

variable "vault_version" {
  default = "1.11.1-ent"
}
