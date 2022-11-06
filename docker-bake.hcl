variable "ORGANIZATION" {
  default = "trailmix"
  # description = "The organization you are exporting from github cloud."
}
variable "SOURCE_TYPE" {
  default = "organization"
  # description = "Are you exporting a organization or user?"
}
variable "SOURCE_TOKEN" {
  default = ""
  # description = "A github cloud PAT that has org:repo scope on the organization you are exporting."
}
variable "TARGET_HOSTNAME" {
  default = ""
  # description = "The hostname of the github enterprise server you are importing an organization to."
}
variable "TARGET_SSH_PORT" {
  default = 122
  # description = "The port of the github enterprise server you are importing an organization to."
}
variable "TARGET_SSH_USER" {
  default = "admin"
  # description = "The admin user of the github enterprise server you are importing an organization to."
}
variable "TARGET_USER" {
  default = ""
  # description = "A github enterprise PAT user that can import the organization."
}
variable "TARGET_TOKEN" {
  default = ""
  # description = "A github enterprise PAT that can import the organization."
}
variable "SSH_AUTH_SOCK" {
  default = "/tmp/ssh_agent.sock"
  # description = "An ssh socket that has a SSH key that can access the github enterprise server."
}
target "docker-metadata-action" {}
target "cache" {
  cache-from = ["type=registry"]
  cache-to   = ["type=inline"]
}
target "export" {
  inherits = ["cache", "docker-metadata-action"]
  target   = "export"
  args = {
    ORGANIZATION = "${ORGANIZATION}"
    SOURCE_TOKEN = "${SOURCE_TOKEN}"
    SOURCE_TYPE  = "${SOURCE_TYPE}"
  }
  output = ["type=local,dest=out/"]
}
target "import" {
  inherits = ["cache", "docker-metadata-action"]
  ssh      = ["default=${SSH_AUTH_SOCK}"]
  target   = "import"
  args = {
    ORGANIZATION    = "${ORGANIZATION}"
    TARGET_USER     = "${TARGET_USER}"
    TARGET_TOKEN    = "${TARGET_TOKEN}"
    TARGET_HOSTNAME = "${TARGET_HOSTNAME}"
    TARGET_SSH_PORT = "${TARGET_SSH_PORT}"
    TARGET_SSH_USER = "${TARGET_SSH_USER}"
  }
  output = ["type=local,dest=out/"]
}
target "output" {
  target   = "output"
  inherits = ["import", "export"]
  output   = ["type=local,dest=out/"]
}
group "default" {
  targets = ["output"]
}
