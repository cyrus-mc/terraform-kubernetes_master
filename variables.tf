###############################################
#         Local Variable definitions          #
###############################################
locals {
  /* use default CoreOS AMI if one not supplied */
  api_instance_ami = "${var.api_instance_ami == "" ? lookup(var.coreos_ami, data.aws_region.current.name) : var.api_instance_ami}"
  wrk_instance_ami = "${var.wrk_instance_ami == "" ? lookup(var.coreos_ami, data.aws_region.current.name) : var.wrk_instance_ami}"

  /* use supplied profile or internally created one */
  api_instance_profile = "${var.api_instance_profile == "" ? aws_iam_instance_profile.kubernetes.id : var.api_instance_profile}"
  wrk_instance_profile = "${var.wrk_instance_profile == "" ? aws_iam_instance_profile.kubernetes.id : var.wrk_instance_profile}"

  /* if a zone is supplied enable route53 support */
  enable_route53 = "${var.route53_zone == "" ? 0 : 1 }"

  /* default tags */
  tags = {
    built-with         = "terraform"
    KubernetesCluster = "${var.name}"
  }
}

variable name { description = "Cluster name" }

variable coreos_ami {
  type = "map"
  default {
    "us-west-2" = "ami-4e804136"
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
  default     = "500"
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
variable api_sg_inbound_rules {
  type    = "list"
  default =
    [
      {
        from_port   = "-1"
        to_port     = "-1"
        protocol    = "all"
        cidr_blocks = "0.0.0.0/0"
      }
    ]
}

variable api_sg_outbound_rules {
  type    = "list"
  default =
    [
      {
        from_port   = "-1"
        to_port     = "-1"
        protocol    = "all"
        cidr_blocks = "0.0.0.0/0"
      }
    ]
}

variable wrk_sg_inbound_rules {
  type    = "list"
  default =
    [
      {
        from_port   = "-1"
        to_port     = "-1"
        protocol    = "all"
        cidr_blocks = "0.0.0.0/0"
      }
    ]
}

variable wrk_sg_outbound_rules {
  type    = "list"
  default =
    [
      {
        from_port   = "-1"
        to_port     = "-1"
        protocol    = "all"
        cidr_blocks = "0.0.0.0/0"
      }
    ]
}

