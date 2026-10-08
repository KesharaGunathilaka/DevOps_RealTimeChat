# Local deploy target: provisions an "EC2 stand-in" container instead of a real
# instance, so the full pipeline can be exercised end to end at no cost. It
# hands Ansible exactly what terraform/aws does: a generated SSH key and an
# inventory for a freshly created Ubuntu 24.04 host.

terraform {
  required_version = ">= 1.5"

  required_providers {
    docker = { source = "kreuzwerker/docker", version = "~> 3.6" }
    tls    = { source = "hashicorp/tls", version = "~> 4.0" }
    local  = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

variable "docker_host" {
  description = "Docker daemon address. Windows: npipe:////./pipe/docker_engine. Linux/macOS: unix:///var/run/docker.sock"
  type        = string
  default     = "npipe:////./pipe/docker_engine"
}

variable "http_port" {
  description = "Host port that stands in for the instance's public port 80"
  type        = number
  default     = 8088
}

provider "docker" {
  host = var.docker_host
}

# ---------------------------------------------------------------- ssh key -----

resource "tls_private_key" "deploy" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "deploy_key" {
  content         = tls_private_key.deploy.private_key_openssh
  filename        = "${path.module}/../../ansible/deploy_key.pem"
  file_permission = "0600"
}

# ---------------------------------------------------------------- network -----

# Ansible's container joins this network to reach the server by name, the way
# it reaches an EC2 instance by public IP.
resource "docker_network" "sim" {
  name = "unichat-sim"
}

# ---------------------------------------------------------------- server ------

resource "docker_image" "standin" {
  name = "unichat-ec2-standin:latest"

  build {
    context = "${path.module}/standin"
  }

  triggers = {
    dockerfile = filesha1("${path.module}/standin/Dockerfile")
    entrypoint = filesha1("${path.module}/standin/entrypoint.sh")
  }
}

# The inner Docker daemon's storage lives on volumes: overlay-on-overlay is not
# supported, so it cannot keep image layers on the container's own filesystem.
# Docker 29 uses the containerd image store, which keeps layers in
# /var/lib/containerd rather than /var/lib/docker, so both need a volume.
resource "docker_volume" "docker_data" {
  name = "unichat-standin-docker"
}

resource "docker_volume" "containerd_data" {
  name = "unichat-standin-containerd"
}

resource "docker_container" "server" {
  name     = "unichat-ec2"
  hostname = "real-chat-server"
  image    = docker_image.standin.image_id

  # Required for systemd as PID 1 and for running a Docker daemon inside.
  privileged    = true
  cgroupns_mode = "host"

  env = ["SSH_PUBLIC_KEY=${tls_private_key.deploy.public_key_openssh}"]

  networks_advanced {
    name = docker_network.sim.name
  }

  # Only the web port is published, mirroring the security group.
  ports {
    internal = 80
    external = var.http_port
  }

  volumes {
    host_path      = "/sys/fs/cgroup"
    container_path = "/sys/fs/cgroup"
  }

  volumes {
    volume_name    = docker_volume.docker_data.name
    container_path = "/var/lib/docker"
  }

  volumes {
    volume_name    = docker_volume.containerd_data.name
    container_path = "/var/lib/containerd"
  }

  tmpfs = {
    "/run"      = ""
    "/run/lock" = ""
  }
}

# ---------------------------------------------------------------- handoff -----

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../ansible/inventory_generated.ini"
  content  = <<-EOT
    [ec2]
    ${docker_container.server.name} ansible_user=ubuntu app_origin=http://localhost:${var.http_port} manage_swap=false
  EOT
}

output "instance_public_ip" {
  description = "Address Ansible uses to reach the server"
  value       = docker_container.server.name
}

output "app_url" {
  description = "Where the deployed app is served"
  value       = "http://localhost:${var.http_port}"
}
