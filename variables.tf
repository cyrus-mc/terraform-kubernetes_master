variable "vpc_id" {
  description = "ID of the VPC where the K8s cluster will be deployed"
}

variable "cluster" {
  description = "Ordinal value denoting the cluster (to allow for multiples in same subnets"
  default     = 0
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
}

variable "ami" {
  description = "The Amazon Machine Image (AMI)"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.large"
}

variable "subnets" {
  description = "List of subnets where instances will be deployed to"
  type        = "list"
}

variable "ip_ranges" {
  description = "List of IP ranges for the above subnets"
  type        = "list"
}

variable "labels" {
  description = "Labels to assign node"
  type        = "map"
}

variable "pod_network" {
  description = "POD network"
}

variable "service_ip_range" {
  description = "Service IP network"
}

variable "iam_instance_profile" {
  description = "The IAM role to attach to K8s nodes"
}

variable "key_pair" {
  description = "SSH key-pair to attach to K8s nodes"
}
