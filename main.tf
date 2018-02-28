/* query data sources */
data aws_subnet "selected" {
  count = "${length(var.subnet_id)}"

  id = "${element(var.subnet_id, count.index)}"
}

data aws_region "current" {}

data aws_route53_zone "main" {
  zone_id = "${var.route53_zone}"
}

// load template that defines policies for k8s nodes
data template_file "policy-kubernetes" {
  template = "${file("${path.module}/templates/policies/kubernetes.tpl")}"
  template = "${file("${format("%s/templates/policies/kubernetes.%s", path.module, replace(replace(var.enable_ark, "/^1/", "ark.tpl"), "/^0/", "tpl"))}")}"

  vars {
    ARK_S3_BUCKET = "${aws_s3_bucket.ark.arn}"
  }
}

/*
  Create user data for each master/etcd instance
*/
data template_file "control-plane" {
  count    =  "${var.api_instance_count}"

  template = "${file("${path.module}/templates/user_data/control-plane.tpl")}"

  vars {

    /* the number of API servers */
    API-SERVERS          = "${var.api_instance_count}"

    HOSTNAME             = "etcd-${count.index + 1}"

    /* the SRV domain for etcd bootstrapping (only relevant with route53 support) */
    SRV-DOMAIN           = "${replace(data.aws_route53_zone.main.name, "/\\.$/", "")}"

    CLUSTER_NAME         = "${var.name}"

    AWS_REGION           = "${data.aws_region.current.name}"

    /* Point at the etcd ELB */
    #ETCD_ELB             = "${aws_elb.etcd.dns_name}"

    /* have to use the null resource here and not aws_instance.private_ip as it results in cicular depdendency */
    ETCD_SERVERS = "${jsonencode(null_resource.etcd_instance_ip.*.triggers.private_ip)}"

    ETCD_TOKEN   = "etcd-cluster-${var.name}"

    CA     = "${indent(6, tls_self_signed_cert.ca.cert_pem)}"
    CA_KEY = "${indent(6, tls_private_key.ca.private_key_pem)}"

    CERTIFICATE     = "${indent(6, tls_locally_signed_cert.apiserver.cert_pem)}"
    CERTIFICATE_KEY = "${indent(6, tls_private_key.apiserver.private_key_pem)}"

  }

}

data template_file "node" {

  count    = "${length(var.workers)}"

  template = "${file("${path.module}/templates/user_data/node.tpl")}"

  vars {
    CLUSTER_NAME = "${var.name}"

    /*
      This is ugly but terraform has issues with nested maps

      This takes a string of format "key,value,key,value,..." and generates
      a map of key, value pairs which is then passed to jsonencode
    */

    LABELS = "${jsonencode(
         zipmap(
           slice(split(",", lookup(var.workers[count.index], "labels", "")), 0,
               length(split(",", lookup(var.workers[count.index], "labels", ""))) / 2 ),
           slice(split(",", lookup(var.workers[count.index], "labels", "")),
               length(split(",", lookup(var.workers[count.index], "labels", ""))) / 2,
               length(split(",", lookup(var.workers[count.index], "labels", ""))) )))}"

    AWS_REGION   = "${data.aws_region.current.name}"

    ETCD_ELB    = "${aws_elb.etcd.dns_name}"
    ETCD_SERVERS = "${jsonencode(aws_instance.api.*.private_ip)}"

    API_ELB = "${aws_elb.api.dns_name}"

    # certificates for kubelet and proxy components
    CA              = "${indent(6, tls_self_signed_cert.ca.cert_pem)}"
    CERTIFICATE     = "${indent(6, tls_locally_signed_cert.worker.cert_pem)}"
    CERTIFICATE_KEY = "${indent(6, tls_private_key.worker.private_key_pem)}"

    PROXY_CERT = "${indent(6, tls_locally_signed_cert.proxy.cert_pem)}"
    PROXY_KEY  = "${indent(6, tls_private_key.proxy.private_key_pem)}"

  }
}

/*
  Generate master/etcd instance IP

  This allows us to decouple implicit dependency between DNS on EC2 resources and instead
  set an explicit dependency between EC2 on DNS
*/
resource null_resource "etcd_instance_ip" {

  count = "${var.api_instance_count}"

  triggers {
    private_ip = "${cidrhost(
                       element(data.aws_subnet.selected.*.cidr_block, count.index),
                       "${((1 + count.index) - (count.index % "${length(data.aws_subnet.selected.*.cidr_block)}") + 20)}"
                     )}"
  }

}

/* create API and etcd EC2 instances */
resource aws_instance "api" {

  /* number of instances, should be an odd number */
  count = "${var.api_instance_count}"

  /* define details about the instance (AMI, type) */
  ami           = "${local.api_instance_ami}"
  instance_type = "${var.api_instance_type}"

  /* define network details about the instance (subnet, private IP) */
  subnet_id              = "${element(var.subnet_id, count.index)}"
  private_ip             = "${element(null_resource.etcd_instance_ip.*.triggers.private_ip, count.index)}"
  vpc_security_group_ids = [ "${aws_security_group.api.id}" ]

  /* define build details (user_data, key, instance profile) */
  key_name             = "${var.key_pair}"
  user_data            = "${element(data.template_file.control-plane.*.rendered, count.index)}"
  iam_instance_profile = "${local.api_instance_profile}"

  /* increase root device space */
  root_block_device {
    volume_size = "${var.root_volume_size}"
  }

  /* add additional volume (/var/lib/docker) */
  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_size = "${var.docker_volume_size}"
    volume_type = "gp2"
  }

  tags  = "${merge(local.tags,
                   map("Name", format("etcd-%d.%s", count.index + 1, var.name)),
                   map("visibility", "private", "role", "api"),
                   var.tags)}"

  /* all DNS entries required for successful etcd bootstrapping */
  depends_on = [ "aws_route53_record.A-etcd",
                 "aws_route53_record.SRV-etcd" ]

}

/* create A record for each etcd server */
resource aws_route53_record "A-etcd" {
  /* route53 support? */
  count   = "${var.api_instance_count * local.enable_route53}"

  name    = "etcd-${count.index + 1}"

  records = [ "${element(null_resource.etcd_instance_ip.*.triggers.private_ip, count.index)}" ]
  ttl     = "300"
  type    = "A"
  zone_id = "${data.aws_route53_zone.main.zone_id}"
}

/* create SRV record used to bootstrap etcd cluster  */
resource aws_route53_record "SRV-etcd" {
  /* route53 support? */
  count = "${local.enable_route53}"

  name = "_etcd-server._tcp"

  ttl     = "300"
  type    = "SRV"
  records = [ "${formatlist("0 0 2380 %v", aws_route53_record.A-etcd.*.fqdn)}" ]

  zone_id = "${data.aws_route53_zone.main.zone_id}"
}

/*
  Create auto-scaling group and corresponding launch confiruation based on the
  number of worker/instance details defined
*/
resource aws_launch_configuration "wrk" {

  count = "${length(var.workers)}"

  name_prefix = "${format("kubernetes.%s.%d", var.name, count.index)}"

  /* increase root device space and set type */
  root_block_device {
    volume_type = "gp2"
    volume_size = "${var.root_volume_size}"
  }

  /* add additional volume (/var/lib/docker) */
  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_size = "${var.docker_volume_size}"
    volume_type = "gp2"
  }

  /* specify the build details (AMI, instance type, key */
  image_id             = "${local.wrk_instance_ami}"
  instance_type        = "${lookup(var.workers[count.index], "instance_type", var.wrk_instance_type)}"
  iam_instance_profile = "${local.wrk_instance_profile}"
  key_name             = "${var.key_pair}"

  /* user data supplied to provision each instance */
  user_data = "${element(data.template_file.node.*.rendered, count.index)}"

  /* specify network details (security group) */
  security_groups = [ "${aws_security_group.wrk.id}" ]

  lifecycle {
    create_before_destroy = true
  }
}


resource aws_autoscaling_group "wrk" {
  /* create as many auto-scaling groups as required */
  count                = "${length(var.workers)}"

  name_prefix = "${format("k8s-%s-%d", var.name, count.index)}"

  /* tie this ASG to the corresponding launch configuration created above */
  launch_configuration = "${element(aws_launch_configuration.wrk.*.name, count.index)}"

  health_check_grace_period = 60

  /* controls how health check is done */
  health_check_type = "EC2"

  force_delete     = true

  /* scaling details */
  min_size         = "${lookup(var.workers[count.index], "auto_scaling.min")}"
  max_size         = "${lookup(var.workers[count.index], "auto_scaling.max")}"
  desired_capacity = "${lookup(var.workers[count.index], "auto_scaling.desired")}"

  /* subnet(s) to launch instances in */
  vpc_zone_identifier = [ "${var.subnet_id}" ]

  tags = [
      {
        key                 = "Name"
        value               = "k8s-worker.${var.name}"
        propagate_at_launch = true
      },
      {
        key                 = "built-with"
        value               = "terraform"
        propagate_at_launch = true
      },
      {
        key                 = "visibility"
        value               = "private"
        propagate_at_launch = true
      },
      {
        key                 = "role"
        value               = "worker"
        propagate_at_launch = true
      },
      {
        key                 = "KubernetesCluster"
        value               = "${var.name}"
        propagate_at_launch = true
      }
    ]

  lifecycle {
    create_before_destroy = true
  }

}

/*
  ELB resource for API service

  Dependencies: aws_instance.master
*/
resource aws_elb "api" {

  name = "k8s-apiserver-${var.name}"

  /* this should be an internal ELB only */
  internal = true

  /* distribute incoming requests evenly across all instances */
  cross_zone_load_balancing = true

  instances    = [ "${aws_instance.api.*.id}" ]
  idle_timeout = 3600

  listener {
    instance_port     = 443
    instance_protocol = "tcp"

    lb_port     = 443
    lb_protocol = "tcp"
  }

  /* define our health check (SSL port 443) */
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2

    timeout = 3
    target  = "SSL:443"

    interval = 30
  }

  /* attach to all subnets an instance can live in */
  subnets         = [ "${var.subnet_id}" ]
  security_groups = [ "${aws_security_group.api.id}" ]

  tags = "${merge(local.tags,
                   map("Name", format("apiserver.%s", var.name)),
                   map("visibility", "private"),
                   var.tags)}"
}

/*
  ELB resource for ETCD service

  Dependencies: aws_instance.master
*/
resource aws_elb "etcd" {

  name = "k8s-etcd-${var.name}"

  /* this should be an internal ELB only */
  internal = true

  /* distribute incoming requests evenly across all instances */
  cross_zone_load_balancing = true

  instances    = [ "${aws_instance.api.*.id}" ]
  idle_timeout = 3600

  listener {
    instance_port     = 2379
    instance_protocol = "tcp"

    lb_port           = 2379
    lb_protocol       = "tcp"
  }

  /* define our health check (TCP on port 2379) */
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2

    timeout = 3
    target  = "TCP:2379"

    interval = 30
  }

  /* attach to all subnets an instance can live in */
  subnets         = [ "${var.subnet_id}" ]
  security_groups = [ "${aws_security_group.api.id}" ]

  tags = "${merge(local.tags,
                   map("Name", format("etcd.%s", var.name)),
                   map("visibility", "private"),
                   var.tags)}"
}

/*
  Define security group controlling inbound and oubound access to
  Kubernetes servers (masters and workers)

*/
resource aws_security_group "api" {
  name = "${format("k8s-%s-api", var.name)}"

  /* link to the correct VPC */
  vpc_id = "${element(data.aws_subnet.selected.*.vpc_id, 0)}"

  tags = "${merge(var.tags,
                  map("Name", format("k8s-%s-api", var.name)),
                  local.tags)}"
}

resource aws_security_group_rule "api-ingress" {
  count = "${length(var.api_sg_inbound_rules)}"

  /* this is an ingress security rule */
  type = "ingress"

  /* specify port range and protocol that is allowed */
  from_port = "${lookup(var.api_sg_inbound_rules[count.index], "from_port")}"
  to_port   = "${lookup(var.api_sg_inbound_rules[count.index], "to_port")}"
  protocol  = "${lookup(var.api_sg_inbound_rules[count.index], "protocol")}"

  /* specify the allowed CIDR block */
  cidr_blocks =  [ "${lookup(var.api_sg_inbound_rules[count.index], "cidr_blocks")}" ]

  /* link to the above created security group */
  security_group_id = "${aws_security_group.api.id}"

}

resource aws_security_group_rule "egress" {
  count = "${length(var.api_sg_outbound_rules)}"

  /* this is an egress security rule */
  type = "egress"

  /* specify port range and protocol that is allowed */
  from_port = "${lookup(var.api_sg_outbound_rules[count.index], "from_port")}"
  to_port   = "${lookup(var.api_sg_outbound_rules[count.index], "to_port")}"
  protocol  = "${lookup(var.api_sg_outbound_rules[count.index], "protocol")}"

  /* specify the allowed CIDR block */
  cidr_blocks = [ "${lookup(var.api_sg_outbound_rules[count.index], "cidr_blocks")}" ]

  /* link to the above created security group */
  security_group_id = "${aws_security_group.api.id}"
}

resource aws_security_group "wrk" {
  name = "${format("k8s-%s-wrk", var.name)}"

  /* link to the correct VPC */
  vpc_id = "${element(data.aws_subnet.selected.*.vpc_id, 0)}"

  tags = "${merge(var.tags,
                  map("Name", format("k8s-%s-wrk", var.name)),
                  local.tags)}"
}

resource "aws_security_group_rule" "wrk-ingress" {
  count = "${length(var.wrk_sg_inbound_rules)}"

  /* this is an ingress security rule */
  type = "ingress"

  /* specify port range and protocol that is allowed */
  from_port = "${lookup(var.wrk_sg_inbound_rules[count.index], "from_port")}"
  to_port   = "${lookup(var.wrk_sg_inbound_rules[count.index], "to_port")}"
  protocol  = "${lookup(var.wrk_sg_inbound_rules[count.index], "protocol")}"

  /* specify the allowed CIDR block */
  cidr_blocks =  [ "${lookup(var.wrk_sg_inbound_rules[count.index], "cidr_blocks")}" ]

  /* link to the above created security group */
  security_group_id = "${aws_security_group.wrk.id}"

}

resource "aws_security_group_rule" "wrk-egress" {
  count = "${length(var.wrk_sg_outbound_rules)}"

  /* this is an egress security rule */
  type = "egress"

  /* specify port range and protocol that is allowed */
  from_port = "${lookup(var.wrk_sg_outbound_rules[count.index], "from_port")}"
  to_port   = "${lookup(var.wrk_sg_outbound_rules[count.index], "to_port")}"
  protocol  = "${lookup(var.wrk_sg_outbound_rules[count.index], "protocol")}"

  /* specify the allowed CIDR block */
  cidr_blocks = [ "${lookup(var.wrk_sg_outbound_rules[count.index], "cidr_blocks")}" ]

  /* link to the above created security group */
  security_group_id = "${aws_security_group.wrk.id}"
}


/*
  Create CNAME record for API ELB

  Dependencies: aws_route53_zone.internal, aws_elb.api
*/
resource aws_route53_record "cname-api" {
  /* route53 support? */
  count = "${local.enable_route53}"

  name    = "apiserver"

  records = [ "${aws_elb.api.dns_name}" ]
  ttl     = "60"
  type    = "CNAME"

  zone_id = "${data.aws_route53_zone.main.zone_id}"
}

/*
  Create CNAME record for etcd ELB

  Dependencies: aws_route53_zone.internal, aws_elb.etcd-internal
*/
resource aws_route53_record "cname-etcd" {
  /* route53 support? */
  count = "${local.enable_route53}"

  name      = "etcd"

  records = [ "${aws_elb.etcd.dns_name}" ]
  ttl     = "60"
  type    = "CNAME"

  zone_id = "${data.aws_route53_zone.main.zone_id}"
}

/* create S3 bucket for ark if enabled */
resource aws_s3_bucket "ark" {
  count = "${var.enable_ark}"

  bucket = "${format("ark.%s", replace(data.aws_route53_zone.main.name, "/\\.$/", ""))}"

  /* the canned ACL to apply */
  acl = "private"

  /* this is used for backups, so versioning should be enabled */
  versioning {
    enabled = true
  }

  tags {
    build-with        = "terraform"
    KubernetesCluster = "${var.name}"
  }
}


resource "aws_iam_policy" "kubernetes" {
  name   = "k8s-${var.name}"
  path   = "/"
  policy = "${data.template_file.policy-kubernetes.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_iam_role" "kubernetes" {
  name = "k8s-${var.name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "kubernetes" {
  name = "k8s-${var.name}"
  role = "${aws_iam_role.kubernetes.name}"
}

/*
  Attach policies to above role
*/
resource "aws_iam_role_policy_attachment" "kubernetes" {
  role       = "${aws_iam_role.kubernetes.name}"
  policy_arn = "${aws_iam_policy.kubernetes.arn}"
}

