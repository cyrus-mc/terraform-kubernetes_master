/*
  Define security group controlling inbound and oubound access to
  Kubernetes servers (masters and workers)

*/
resource "aws_security_group" "kubernetes-master" {

  name = "kubernetes.${var.name}"

  description = "Definition of inbound and outbounc traffic for Kubernetes servers"

  /* link to the correct VPC */
  vpc_id = "${element(data.aws_subnet.selected.*.vpc_id, 0)}"

  /*
    Define ingress rules
  */
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    #cidr_blocks = [ "${var.ip_ranges}" ]
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  /*
    Define egress rules
  */
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  /* tag the resource */
  tags = "${merge(local.tags,
                  map("Name", format("kubernetes.%s", var.name)),
                  var.tags)}"

}
