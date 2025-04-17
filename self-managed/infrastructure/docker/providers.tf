terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.4-alpha.2"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}