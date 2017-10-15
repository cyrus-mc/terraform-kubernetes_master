variable "vpc_id" {
  description = "ID of the VPC where the K8s cluster will be deployed"
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
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.large"
}

variable "subnet_id" {
  description = "List of subnets where instances will be deployed to"
  type        = "list"
}

variable "pod_network" {
  description = "POD network"
  default     = "10.2.0.0/16"
}

variable "service_ip_range" {
  description = "Service IP network"
  default     = "10.3.0.0/24"
}

variable "instance_profile" {
  description = "The IAM role to attach to K8s nodes"
  default     = ""
}

variable "key_pair" {
  description = "SSH key-pair to attach to K8s nodes"
}

variable "enable_route53" {
  description = "Enable route 53 support"
  default     = false
}

variable "root_volume_size" {
  description = "Size of the instance root volume"
  default     = "8"
}

variable "docker_volume_size" {
  description = "Size of the docker volume"
  default     = "100"
}

variable "ansible_server" {
  description = "FQDN or IP of the Ansible server"
}

variable "ansible_callback" {}

variable "ansible_host_key" {}

variable "aws_profile" {
  description = "AWS profile to use for local provisioner"
  default     = "default"
}
