## Kubernetes Infrastructure Stack

[![Build Status](http://jenkins.dat.com/buildStatus/icon?job=DevOps/Terraform/Modules/tf-module-kubernetes/master)](http://jenkins.dat.com/job/DevOps/job/Terraform/job/Modules/job/tf-module-kubernetes/)

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
  `name`          | Kubernetes cluster name. | string | -
  `coreos_ami`    | AMI for the CoreOS image to use | string. | `us-west-2 = "ami-6666fe1e"`
  `api_instance_count` | Number of API servers to provision. | string | `3`
  `api_instance_type`  | EC2 instance type of API servers. | string | `t2.large`
  `api_instance_profile` | IAM instance profile to attach to API instances (if not set module will create one). | string | `""`
  `api_instance_ami` | AMI to provision API instances from. | string | `var.coreos_ami`
  `wrk_instance_type` | EC2 instance type of the worker servers. | string | `t2.large`
  `wrk_instance_profile` | IAM instance profile to attach to the worker instances (if not set module will create one). | string | `""`
  `wrk_instance_ami` | AMI to provision worker instances from. | string | `var.coreos_ami`
  `subnet_id` | Subnets to provision API and worker instances in. | list | -
  `key_pair` | EC2 SSH KeyPair to assign to API and worker instances. | string | -
  `workers` | List of maps that define the worker auto-scaling groups to create. | list | `[]`
  `api_lb_security_group_id` | Security group ID to attach to the API ELB. | list | -
  `etcd_lb_security_group_id` | Security group ID to attach to the etcd ELB. | list | -
  `api_instance_security_group_id` | Security group ID to attach to the API instances. | list | -
  `worker_instance_security_group_id` | Security group ID to attach to the worker instances. | list | -
  `enable_ark` | Flag controlling whether Heptio Ark support is enabled. | boolean | `false`
  `tags` | A mapping of tags to assign to the resource(s). | map | `{}`


### Ouputs
- - - -

This module exposes the following outputs:

  Name          | Description   | Type
  ------------- | ------------- | -------------
  `api_elb` | The DNS name of the API ELB | string
  `admin-key` | Administrator private key data in PEM format | string
  `admin-cert` | Administrator certificate data in PEM format | string
  `autoScalingGroupName` | Worker autoscaling group name(s) | list


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
