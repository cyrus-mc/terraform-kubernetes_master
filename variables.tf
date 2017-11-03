###############################################
#         Local Variable definitions          #
###############################################
locals {

  /* lookup the AMI based on region */
  region_ami = "${lookup(var.coreos_ami, var.region)}"

  /*
    Either use supplied AMI or lookup based on region
  */
  ami = "${var.ami == "" ? local.region_ami : var.ami}"

  /*
    Default tags (loacl so you can't over-ride)
  */
  tags = {
    builtWith         = "terraform"
    KubernetesCluster = "${var.name}"
  }

}

variable "region" {
  description = "AWS region where the K8s cluster will be deployed"
}

variable "internal-tld" {
  description = "Top-level domain for K8s clusters (defaults to k8s)"
  default     = "k8s"
}

variable "name" {
  description = "Cluster name (used to create private hosted zone)"
}

/* variables controlling instance creation (number, AMI, type) */
variable "servers" {
  description = "Number of instances to create (should be an odd number)"
  default     = 3
}

variable "ami" {
  description = "The Amazon Machine Image (AMI)"
  default     = ""
}

variable "coreos_ami" {
  description = "Current list of CoreOS AMI based on region"
  type        = "map"
  default {
    "us-west-2" = "ami-4e804136"
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.large"
}

variable "subnet_id" {
  description = "List of subnets where instances will be deployed to"
  type        = "list"
}

variable "instance_profile" {
  description = "The IAM role to attach to K8s nodes"
  default     = ""
}

variable "key_pair" {
  description = "SSH key-pair to attach to K8s nodes"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  default     = {}
}

variable "enable_route53" {
  description = "Enable route 53 support"
  default     = false
}

variable "root_volume_size" {
  description = "Size of the instance root volume"
  default     = "100"
}

variable "docker_volume_size" {
  description = "Size of the docker volume"
  default     = "500"
}

variable "ansible_server" {
  description = "FQDN or IP of the Ansible server"
}

variable "ansible_callback" {}

variable "ansible_host_key" {}

/*
  List of maps that defines worker instance groups to deploy

  ex:
  [
    {
      auto_scaling.min     = "1"
      auto_scaling.max     = "6"
      auto_scaling.desired = "2"
      labels               = "namespace,role,default.testing"
    }
  ]
*/
variable "workers" {
  default = []
}
