module "kubernetes" {
  source = "../"

  name     = "test"

  key_pair  = "user_keypair"

  subnet_id = [ "subnet-b1386cd6", "subnet-77325d3e" ]

  /* specify security groups for the various components */
  api_lb_security_group_id          = [ "sg-584bd223" ]
  etcd_lb_security_group_id         = [ "sg-584bd223" ]
  api_instance_security_group_id    = [ "sg-584bd223" ]
  worker_instance_security_group_id = [ "sg-584bd223" ]

  /* create 3 API instances */
  api_instance_count = 3
  route53_zone = "Z1AB0R0N1T7J8R"

  /* don't provide support for Heptio Ark */                                                                            enable_ark = true

  /* create 1 worker autoScaling groups */
  workers =
    [
      {
        auto_scaling.min     = "0"
        auto_scaling.max     = "4"
        auto_scaling.desired = "3"
        instance_type        = "t2.xlarge"
        labels               = "namespace,role,test,services"
      }
    ]

  /* additional tags */
  tags = "${merge(map("product", "Kubernetes"),
                  map("environment", "development"),
                  map("os", "linux"),
                  map("jenkinsPipeline", "DevOps/Ansible/playbook-kubernetes/master"),
                  map("k8s.io/cluster-autoscaler/enabled", ""),
                  map("k8s.io/cluster-autoscaler/test", ""))}"
}
