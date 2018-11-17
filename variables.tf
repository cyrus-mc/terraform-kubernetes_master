###############################################
#         Local Variable definitions          #
###############################################
locals {
  /* use default CoreOS AMI if one not supplied */
  api_instance_ami = "${var.api_instance_ami == "" ? lookup(var.coreos_ami, data.aws_region.current.name) : var.api_instance_ami}"
  wrk_instance_ami = "${var.wrk_instance_ami == "" ? lookup(var.coreos_ami, data.aws_region.current.name) : var.wrk_instance_ami}"

  /* if a zone is supplied enable route53 support */
  enable_route53 = "${var.route53_zone == "" ? 0 : 1 }"

  /* default tags */
  tags = {
    built-with         = "terraform"
    KubernetesCluster = "${var.name}"
  }

  /* convert tags to format needed by auto-scaling group */
  tag_keys   = "${concat(keys(var.tags), keys(local.tags))}"
  tag_values = "${concat(values(var.tags), values(local.tags))}"

  /* define a structure for the keys of the dicts that the asg block requires */
  key_list = "${list("key", "value", "propagate_at_launch")}"

  list0 = "${list(
      element(concat(local.tag_keys, list("")), 0),
      element(concat(local.tag_values, list("")), 0),
      "true"
    )}"

  list1 = "${list(
      element(concat(local.tag_keys, list("")), 1),
      element(concat(local.tag_values, list("")), 1),
      "true"
    )}"

  list2 = "${list(
      element(concat(local.tag_keys, list("")), 2),
      element(concat(local.tag_values, list("")), 2),
      "true"
    )}"

  list3 = "${list(
      element(concat(local.tag_keys, list("")), 3),
      element(concat(local.tag_values, list("")), 3),
      "true"
    )}"

  list4 = "${list(
      element(concat(local.tag_keys, list("")), 4),
      element(concat(local.tag_values, list("")), 4),
      "true"
    )}"

  list5 = "${list(
      element(concat(local.tag_keys, list("")), 5),
      element(concat(local.tag_values, list("")), 5),
      "true"
    )}"

  list6 = "${list(
      element(concat(local.tag_keys, list("")), 6),
      element(concat(local.tag_values, list("")), 6),
      "true"
    )}"

  list7 = "${list(
      element(concat(local.tag_keys, list("")), 7),
      element(concat(local.tag_values, list("")), 7),
      "true"
    )}"

  list8 = "${list(
      element(concat(local.tag_keys, list("")), 8),
      element(concat(local.tag_values, list("")), 8),
      "true"
    )}"

  list9 = "${list(
      element(concat(local.tag_keys, list("")), 9),
      element(concat(local.tag_values, list("")), 9),
      "true"
    )}"

  # Construct list of dicts in required format by zipmapping the value lists with the standard key list
  # Slicing to the length of the map of tags so we dont get blank or repeating tags starting from first non-default value
  tags_asg_format = "${slice(list(
      zipmap(
        local.key_list,
        local.list0
      ),
      zipmap(
        local.key_list,
        local.list1
      ),
      zipmap(
        local.key_list,
        local.list2
      ),
      zipmap(
        local.key_list,
        local.list3
      ),
      zipmap(
        local.key_list,
        local.list4
      ),
      zipmap(
        local.key_list,
        local.list5
      ),
      zipmap(
        local.key_list,
        local.list6
      ),
      zipmap(
        local.key_list,
        local.list7
      ),
      zipmap(
        local.key_list,
        local.list8
      ),
      zipmap(
        local.key_list,
        local.list9
      )
    ), 0, min(length(local.tag_keys), 10))
  }"
}

variable name { description = "Cluster name" }

variable coreos_ami {
  type = "map"
  default {
    "us-west-2" = "ami-6666fe1e"
  }
}

/* api EC2 settings */
variable api_instance_count   { default = 3 }
variable api_instance_type    { default = "t2.large" }
variable api_instance_profile { default = "" }
variable api_instance_ami     { default = "" }

/* worker EC2 settings */
variable wrk_instance_type    { default = "t2.large" }
variable wrk_instance_profile { default = "" }
variable wrk_instance_ami     { default = "" }

variable subnet_id { type = "list" }

variable key_pair {}

variable tags {
  default     = {}
}

variable route53_zone   {}

variable "root_volume_size" {
  description = "Size of the instance root volume"
  default     = "100"
}

variable "docker_volume_size" {
  description = "Size of the docker volume"
  default     = "200"
}

/*
  List of maps that defines worker instance groups to deploy

  ex:
  [
    {
      instance_type        = "t2.xlarge"
      auto_scaling.min     = "1"
      auto_scaling.max     = "6"
      auto_scaling.desired = "2"
      labels               = "namespace,role,default,testing"
    }
  ]
*/
variable workers {
  default = []
}

/* security group settings */
variable "api_lb_security_group_id"          { type = "list" }
variable "etcd_lb_security_group_id"         { type = "list" }
variable "api_instance_security_group_id"    { type = "list" }
variable "worker_instance_security_group_id" { type = "list" }

/* enable Heptio ARK support */
variable enable_ark { default = false }
