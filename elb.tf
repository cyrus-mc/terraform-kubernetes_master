/*
  ELB resource for API service

  Dependencies: aws_instance.master
*/
resource "aws_elb" "api-internal" {

  name = "apiserver-${var.name}-${var.internal-tld}"

  /* this should be an internal ELB only */
  internal = true

  /* distribute incoming requests evenly across all instances */
  cross_zone_load_balancing = true

  instances    = [ "${aws_instance.master.*.id}" ]
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
  security_groups = [ "${aws_security_group.kubernetes-master.id}" ]

  tags = "${merge(local.tags,
                   map("Name", format("apiserver.%s", var.name)),
                   map("visibility", "private"),
                   var.tags)}"
}

/*
  ELB resource for ETCD service

  Dependencies: aws_instance.master
*/
resource "aws_elb" "etcd-internal" {

  name = "etcd-${var.name}-${var.internal-tld}"

  /* this should be an internal ELB only */
  internal = true

  /* distribute incoming requests evenly across all instances */
  cross_zone_load_balancing = true

  instances    = [ "${aws_instance.master.*.id}" ]
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
  security_groups = [ "${aws_security_group.kubernetes-master.id}" ]

  tags = "${merge(local.tags,
                   map("Name", format("etcd.%s", var.name)),
                   map("visibility", "private"),
                   var.tags)}"
}
