/*
  Define security group controlling inbound and oubound access to
  Kubernetes API servers (masters)

*/
resource "aws_security_group" "kubernetes-master" {

  name = "kubernetes-master-${var.name}"

  description = "Define inbound and outbound traffic for Kubernetes API server nodes"

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

  tags {
    builtWidth        = "terraform"
    KubernetesCluster = "${var.name}"
    Name              = "kubernetes-master-${var.name}"
  }

}
