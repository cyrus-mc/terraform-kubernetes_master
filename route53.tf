/*
  Create nternal cluster specific hosted DNS zone used to facilitate etcd
  bootstrapping via SRV records

  Dependencies: var.vpc_id
*/
resource "aws_route53_zone" "internal" {

  comment = "Kubernetes cluster ${var.name}"

  name    = "${var.name}.${var.internal-tld}"

  tags {
    builtWith         = "terraform"
    domain            = "${var.name}.${var.internal-tld}"
    KubernetesCluster = "${var.name}"
  }

  /* what VPC to attach zone to (there should be no overlap between zones
     attached to a VPC
  */
  vpc_id = "${var.vpc_id}"
}

/*
  Create A records for each etcd instance

  Dependencies: aws_route53_zone.internal, null_resource.etcd_instance_ip
*/
resource "aws_route53_record" "A-etcd" {

  count   = "${var.servers}"
  
  name    = "etcd-${count.index + 1}"

  records = [ "${element(null_resource.etcd_instance_ip.*.triggers.private_ip, count.index)}" ]
  ttl     = "300"
  type    = "A"
  zone_id = "${aws_route53_zone.internal.zone_id}"

}

/*
  Create SRV record used to bootstrap etcd cluster

  Dependencies: aws_route53_zone.internal, aws_route53_record.A-etcd
*/
resource "aws_route53_record" "SRV-etcd" {

  name = "_etcd-server._tcp"

  ttl     = "300"
  type    = "SRV"
  records = [ "${formatlist("0 0 2380 %v", aws_route53_record.A-etcd.*.fqdn)}" ]

  zone_id = "${aws_route53_zone.internal.zone_id}"

}

/*
  Create CNAME record for API ELB

  Dependencies: aws_route53_zone.internal, aws_elb.api-internal
*/
resource "aws_route53_record" "CNAME-apiserver" {

  name = "apiserver"

  records = [ "${aws_elb.api-internal.dns_name}" ]
  ttl     = "60"
  type    = "CNAME"

  zone_id = "${aws_route53_zone.internal.zone_id}"

}

/*
  Create CNAME record for etcd ELB

  Dependencies: aws_route53_zone.internal, aws_elb.etcd-internal
*/
resource "aws_route53_record" "CNAME-etcd" {

  name = "etcd"

  records = [ "${aws_elb.etcd-internal.dns_name}" ]
  ttl     = "60"
  type    = "CNAME"

  zone_id = "${aws_route53_zone.internal.zone_id}"

}

# outputs
output "route53_zone" {
  value = "${aws_route53_zone.internal.zone_id}"
}
