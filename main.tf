# ----------------------------------------------------------------------------------------------------------------------
#
# Author: Infrastructure
# 
# ----------------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------------
# DON'T TOUCH!
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0.0"
  backend "s3" {
    region = "us-west-2"
    bucket = "poklsdf-terraform"
    key    = "states/template.tfstate"
  }

  required_providers {
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "3.63.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile # Please see the .tfvars file and the readme for more information about this.
}