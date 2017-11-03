output "api_elb" {
  value = "${aws_elb.api-internal.dns_name}"
}

output "api_elb_cname" {
  value = "${aws_route53_record.CNAME-apiserver.fqdn}"
}

output "etcd_elb" {
  value = "${aws_elb.etcd-internal.dns_name}"
}

output "etcd_elb_cname" {
  value = "${aws_route53_record.CNAME-etcd.fqdn}"
}

output "etcd_private_ips" {
  value = [ "${aws_instance.master.*.private_ip}" ]
}

output "instance_profile" {
  value = "${aws_iam_instance_profile.kubernetes.name}"
}
