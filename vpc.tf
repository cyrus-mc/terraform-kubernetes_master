/*
  Define security group controlling inbound and oubound access to
  Kubernetes servers (masters and workers)

*/
resource "aws_security_group" "kubernetes-master" {

  name = "kubernetes.${var.name}"

  description = "Definition of inbound and outbounc traffic for Kubernetes servers"

  /* link to the correct VPC */
  vpc_id = "${element(data.aws_subnet.selected.*.vpc_id, 0)}"

  /* tag the resource */
  tags = "${merge(local.tags,
                  map("Name", format("kubernetes.%s", var.name)),
                  var.tags)}"

}

resource "aws_security_group_rule" "ingress" {

  /* this is an ingress security rule */
  type = "ingress"

  /* specify port range and protocol that is allowed */
  from_port = 0
  to_port   = 0
  protocol  = "-1"

  /* specify the allowed CIDR block */
  cidr_blocks = [ "0.0.0.0/0" ]

  /* link to the above created security group */
  security_group_id = "${aws_security_group.kubernetes-master.id}"

}

resource "aws_security_group_rule" "egress" {

  /* this is an egress security rule */
  type = "egress"

  /* specify the port range and protocol that is allowed */
  from_port = 0
  to_port   = 0
  protocol  = "-1"

  /* specify the allowed CIDR block */
  cidr_blocks = [ "0.0.0.0/0" ]

  /* link to the above created security group */
  security_group_id = "${aws_security_group.kubernetes-master.id}"

}
