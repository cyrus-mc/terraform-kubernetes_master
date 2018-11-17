## Kubernetes Infrastructure Stack

[![Build Status](http://jenkins.services.dat.internal/buildStatus/icon?job=DevOps/Terraform/Modules/tf-module-kubernetes/master)](http://jenkins.services.dat.internal/job/DevOps/job/Terraform/job/Modules/job/tf-module-kubernetes/)

Terraform module used to create, within AWS, the necessary infrastructure to run a Kubernetes cluster.

Currently this module creates:

   * API instances
   * Worker auto-scaling group(s)
   * ELB for API
   * ELB for etcd cluster
   * SSL certificates

## Requirements
- - - -

This module requires:

   -  [AWS Provider](https://github.com/terraform-providers/terraform-provider-aws) `>= 1.17.0`
   -  [Template Provider](https://github.com/terraform-providers/terraform-provider-template) `>= 1.0.0`
   -  [TLS Provider](https://github.com/terraform-providers/terraform-provider-tls) `>= 1.1.0`
   -  [Null Provider](https://github.com/terraform-providers/terraform-provider-null) `>= 1.0.0`

### Inputs
- - - -

This module takes the following inputs:

  Name          | Description   | Type          | Default
  ------------- | ------------- | ------------- | -------------
  name          | Kubernetes cluster name | String |
  coreos_ami    | AMI for the CoreOS image to use | String | us-west-2 = "ami-6666fe1e"
  api_instance_count | Number of API servers to provision | Number | 3
  api_instance_type  | EC2 instance type of API servers | String | t2.large
  api_instance_profile | IAM instance profile to attach to API instances (if not set module will create one) | String | ""
  api_instance_ami | AMI to provision API instances from | String | coreos_ami
  wrk_instance_type | EC2 instance type of the worker servers | String | t2.large
  wrk_instance_profile | IAM instance profile to attach to the worker instances ( not not set module will create one) | String | ""
  wrk_instance_ami | AMI to provision worker instances from | String | coreos_ami
  subnet_id | Subnets to provision API and worker instances in | List |
  key_pair | EC2 SSH KeyPair to assign to API and worker instances | String |
  workers | List of maps that define the worker auto-scaling groups to create | List | []
  api_lb_security_group_id | Security group ID to attach to the API ELB | List |
  etcd_lb_security_group_id | Security group ID to attach to the etcd ELB | List |
  api_instance_security_group_id | Security group ID to attach to the API instances | List |
  worker_instance_security_group_id | Security group ID to attach to the worker instances | List |
  enable_ark | Flag controlling whether Heptio Ark support is enabled | Boolean | false
  tags | Additional tags to apply to created resources | Map | {}


### Ouputs
- - - -

This module exposes the following outputs:

  Name          | Description   | Type
  ------------- | ------------- | -------------
  api_elb | The DNS name of the API ELB | String
  admin-key | Administrator private key data in PEM format | String
  admin-cert | Administrator certificate data in PEM format | String
  autoScalingGroupName | Worker autoscaling group name(s) | List


## Usage
- - - -

Create a Kubernetes cluster with cluster name test.

```hcl

module "kubernetes" {
  source = "git::ssh://git@bitbucket.org/dat/tf-module-kubernetes.git?ref=master"

  name     = "test"

  key_pair  = "user_keypair"

  subnet_id = [ "subnet-b1386cd6", "subnet-77325d3e" ]

  /* specify security groups for the various components */
  api_lb_security_group_id          = [ "sg-584bd223" ]
  etcd_lb_security_group_id         = [ "sg-584bd223" ]
  api_instance_security_group_id    = [ "sg-584bd223" ]
  worker_instance_security_group_id = [ "sg-584bd223" ]

  /* create 3 API instances */
  api_instance_count = 3

  route53_zone = "Z1AB0R0N1T7J8R"

  /* don't provide support for Heptio Ark */
  enable_ark = false

  /* create 1 worker autoScaling groups */
  workers =
    [
      {
        auto_scaling.min     = "0"
        auto_scaling.max     = "4"
        auto_scaling.desired = "3"
        instance_type        = "t2.xlarge"
        labels               = "namespace,role,test,services"
      }
    ]

  /* additional tags */
  tags = "${merge(var.tags,
                  map("product", "Kubernetes"),
                  map("environment", "development"),
                  map("os", "linux"),
                  map("jenkinsPipeline", "DevOps/Ansible/playbook-kubernetes/master"),
                  map("k8s.io/cluster-autoscaler/enabled", ""),
                  map("k8s.io/cluster-autoscaler/test", ""))}"
}

```
