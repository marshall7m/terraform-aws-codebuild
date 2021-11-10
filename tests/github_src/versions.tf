terraform {
  required_version = ">= 1.0.0"
  required_providers {
    test = {
      source = "terraform.io/builtin/test"
    }
  }
}
provider "test" {}