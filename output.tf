output "api_elb" {
  value = "${aws_elb.api-internal.dns_name}"
}

output "etcd_elb" {
  value = "${aws_elb.etcd-internal.dns_name}"
}
