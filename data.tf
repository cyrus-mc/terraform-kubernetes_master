/*
  Query subnet details
*/
data "aws_subnet" "selected" {
  count = "${length(var.subnet_id)}"

  id = "${element(var.subnet_id, count.index)}"
}

/*
  Create user data for each master/etcd instance
*/
data "template_file" "cloud-config" {

  count    =  "${var.servers}"

  template = "${file("${path.module}/master-cloud-config.yml")}"

  vars {

    /* the number of API servers */
    API-SERVERS          = "${var.servers}"

    HOSTNAME             = "etcd-${count.index + 1}"

    /* the SRV domain for etcd bootstrapping (only relevant with route53 support) */
    SRV-DOMAIN           = "${var.name}.${var.internal-tld}"

    CLUSTER_NAME         = "${var.name}"

    AWS_REGION           = "${var.region}"

    /* Point at the etcd ELB */
    #ETCD_ELB             = "${aws_elb.etcd-internal.dns_name}"

    /* have to use the null resource here and not aws_instance.private_ip as it results in cicular depdendency */
    ETCD_SERVERS = "${jsonencode(null_resource.etcd_instance_ip.*.triggers.private_ip)}"

    ETCD_TOKEN   = "etcd-cluster-${var.name}"

    ANSIBLE_HOST_KEY     = "${var.ansible_host_key}"
    ANSIBLE_CALLBACK_URL = "https://${var.ansible_server}/api/v1/job_templates/${var.ansible_callback}/callback/"

    CA              = "${indent(6, tls_self_signed_cert.ca.cert_pem)}"
    CERTIFICATE     = "${indent(6, tls_locally_signed_cert.apiserver.cert_pem)}"
    CERTIFICATE_KEY = "${indent(6, tls_private_key.apiserver.private_key_pem)}"

  }

}

data "template_file" "worker-config" {

  count    = "${length(var.workers)}"

  template = "${file("${path.module}/worker-cloud-config.yml")}"

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


    AWS_REGION = "${var.region}"

    ETCD_ELB     = "${aws_elb.etcd-internal.dns_name}"
    ETCD_SERVERS = "${jsonencode(aws_instance.master.*.private_ip)}"

    API_ELB        = "${aws_elb.api-internal.dns_name}"

    ANSIBLE_HOST_KEY     = "testing"
    ANSIBLE_CALLBACK_URL = "testing"

    CA              = "${indent(6, tls_self_signed_cert.ca.cert_pem)}"
    CERTIFICATE     = "${indent(6, tls_locally_signed_cert.worker.cert_pem)}"
    CERTIFICATE_KEY = "${indent(6, tls_private_key.worker.private_key_pem)}"

  }
}
