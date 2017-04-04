/*
  Generate master/etcd instance IP

  This allows us to decouple implicit dependency between DNS on EC2 resources and instead
  set an explicit dependency between EC2 on DNS
*/
resource "null_resource" "etcd_instance_ip" {

  count = "${var.servers}"

  triggers {
    private_ip = "${cidrhost(element(var.ip_ranges, count.index), "${((1 + count.index) - (count.index %
 "${length(var.ip_ranges)}") + 10)}")}"
  }

}

/*
  Create our API and etcd instances

  This is a one time creation due to fact etcd goes through an initial
  bootstrap

  Dependencies: aws_route53_record.A-etcd, aws_route53_record.SRV-etcd
*/
resource "aws_instance" "master" {

  /* number of instances, should be an odd number */
  count = "${var.servers}"

  /* define details about the instance (AMI, type) */
  ami           = "${var.ami}"
  instance_type = "${var.instance_type}"

  /* define network details about the instance (subnet, private IP) */
  subnet_id  = "${element(var.subnets, count.index)}"
  private_ip = "${element(null_resource.etcd_instance_ip.*.triggers.private_ip, count.index)}"

  /* define build details (user_data, key, instance profile) */
  key_name             = "${var.key_pair}"
  user_data            = "${element(data.template_file.cloud-config.*.rendered, count.index)}"
  iam_instance_profile = "${var.iam_instance_profile}"

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

/*
  Use local provisioner to fire off Lambda function which generates Cluster certificates.

  This should only ever run once. If you ever need to regenerate certificates you are most likely
  looking at a complete teardown and rebuild of the cluster.
*/
resource "null_resource" "generate-certs" {

  /* use awscli (must be installed on users system) */
  provisioner "local-exec" {
    command = "aws lambda invoke --invocation-type RequestResponse --function-name k8s-cluster-certs --region ${var.region} --payload '{\"cluster-name\": \"${var.name}\", \"internal-tld\": \"${var.internal-tld}\", \"region\": \"${var.region}\"}' lambda.out"
  }

  /*
    Again, this should never really happen. And even if it does, unless the bucket for this
    cluster has been deleted the lambda function won't actually generate new certificates (nor
    would you want it to)
  */
  triggers {
    master_instance_id = "${join(",", aws_instance.master.*.id)}"
  }
}

# will need these later
output "etcd_private_ips" {
  value = [ "${aws_instance.master.*.private_ip}" ]
}
