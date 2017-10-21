###################################################
#          Local Variable Definitions             #
###################################################
locals {

  instance_profile = "${var.instance_profile == "" ? aws_iam_instance_profile.kubernetes.id : var.instance_profile}"
}

/*
  Generate master/etcd instance IP

  This allows us to decouple implicit dependency between DNS on EC2 resources and instead
  set an explicit dependency between EC2 on DNS
*/
resource "null_resource" "etcd_instance_ip" {

  count = "${var.servers}"

  triggers {
    private_ip = "${cidrhost(element(data.aws_subnet.selected.*.cidr_block, count.index), "${((1 + count.index) - (count.index %
 "${length(data.aws_subnet.selected.*.cidr_block)}") + 10)}")}"
  }

}

/*
  Create our API and etcd instances

  This is a one time creation due to fact etcd goes through an initial
  bootstrap

*/
resource "aws_instance" "master" {

  /* number of instances, should be an odd number */
  count = "${var.servers}"

  /* define details about the instance (AMI, type) */
  ami           = "${var.ami}"
  instance_type = "${var.instance_type}"

  /* define network details about the instance (subnet, private IP) */
  subnet_id  = "${element(var.subnet_id, count.index)}"
  private_ip = "${element(null_resource.etcd_instance_ip.*.triggers.private_ip, count.index)}"
  vpc_security_group_ids = [ "${aws_security_group.kubernetes-master.id}" ]

  /* define build details (user_data, key, instance profile) */
  key_name             = "${var.key_pair}"
  user_data            = "${element(data.template_file.cloud-config.*.rendered, count.index)}"
  iam_instance_profile = "${local.instance_profile}"

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

  tags {
    builtWith         = "terraform"
    KubernetesCluster = "${var.name}"
    Name              = "k8s-etcd-${count.index + 1}"
    role              = "etcd,apiserver"
    visibility        = "private"
  }

  /* all DNS entries required for successful etcd bootstrapping */
  depends_on = [ "aws_route53_record.A-etcd",
                 "aws_route53_record.SRV-etcd" ]

}

resource "aws_launch_configuration" "workers" {

  count = "${length(var.workers)}"

  root_block_device {
    volume_size = "100"
  }

  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_size = "500"
    volume_type = "gp2"
  }

  image_id = "${var.ami}"

  iam_instance_profile = "${local.instance_profile}"
  instance_type        = "${lookup(var.workers[count.index], "instance_type", var.instance_type)}"

  key_name             = "${var.key_pair}"

  security_groups = [ "${aws_security_group.kubernetes-master.id}" ]
  /* user data supplied to provision each instance */
  user_data = "${element(data.template_file.worker-config.*.rendered, count.index)}"

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "workers" {

  /* create as many auto-scaling groups as required */
  count                = "${length(var.workers)}"

  /* tie this ASG to the corresponding launch configuration created above */
  launch_configuration = "${element(aws_launch_configuration.workers.*.name, count.index)}"

  health_check_grace_period = 60
  health_check_type         = "EC2"

  force_delete     = true

  min_size         = "${lookup(var.workers[count.index], "auto_scaling.min")}"
  max_size         = "${lookup(var.workers[count.index], "auto_scaling.max")}"
  desired_capacity = "${lookup(var.workers[count.index], "auto_scaling.desired")}"

  /* subnet(s) to launch instances in */
  vpc_zone_identifier = [ "${var.subnet_id}" ]

  lifecycle {
    create_before_destroy = true
  }

}
