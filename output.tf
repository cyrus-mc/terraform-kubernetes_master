output "api_elb" { value = "${aws_elb.api.dns_name}" }
#
#output "api_elb_cname" { value = "${aws_route53_record.CNAME-apiserver.*.fqdn}" }

#output "etcd_elb" { value = "${aws_elb.etcd-internal.dns_name}" }

#output "etcd_elb_cname" { value = "${aws_route53_record.CNAME-etcd.*.fqdn}" }

#output "etcd_private_ips" { value = [ "${aws_instance.master.*.private_ip}" ] }

#output "instance_profile" { value = "${aws_iam_instance_profile.kubernetes.name}" }

#output "route53_zone" { value = "${aws_route53_zone.internal.*.zone_id}" }

output "admin-key" { value = "${tls_private_key.admin.private_key_pem}" }

output "admin-cert" { value = "${tls_locally_signed_cert.admin.cert_pem}" }

#output "trigger" { value = ["${aws_instance.master.*.private_ip}"] }
