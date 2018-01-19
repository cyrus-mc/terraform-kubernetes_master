/* create the CA certificate */
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_self_signed_cert" "ca" {
  key_algorithm   = "RSA"
  private_key_pem = "${tls_private_key.ca.private_key_pem}"

  subject {
    country             = "US"
    organization        = "Kubernetes"
    organizational_unit = "CA"
    common_name         = "kubernetes-certificate-authority"
  }

  validity_period_hours = 87600

  is_ca_certificate = true
  allowed_uses      = [ "cert_signing",
                        "key_encipherment",
                        "server_auth",
                        "client_auth" ]
}

resource "tls_private_key" "apiserver" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "apiserver" {
  key_algorithm   = "RSA"
  private_key_pem = "${tls_private_key.apiserver.private_key_pem}"

  dns_names = [
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster.local",
    "*.${var.region}.elb.amazonaws.com"
  ]

  ip_addresses = [
    "10.3.0.1"
  ]

  subject {
    common_name = "kube-apiserver"
  }
}

resource "tls_locally_signed_cert" "apiserver" {
  cert_request_pem   = "${tls_cert_request.apiserver.cert_request_pem}"
  ca_key_algorithm   = "RSA"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  validity_period_hours = 87600

  allowed_uses = [
    "server_auth"
  ]
}

resource "tls_private_key" "worker" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "worker" {
  key_algorithm    = "RSA"
  private_key_pem  = "${tls_private_key.worker.private_key_pem}"

  subject {
    country             = "US"
    organization        = "system:nodes"
    organizational_unit = "Kubernetes kubelet"
    common_name         = "kubelet"
  }
}

resource "tls_locally_signed_cert" "worker" {
  cert_request_pem   = "${tls_cert_request.worker.cert_request_pem}"
  ca_key_algorithm   = "RSA"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  validity_period_hours = 87600

  allowed_uses = [
    "client_auth"
  ]

}

resource "tls_private_key" "proxy" {

  algorithm = "RSA"
  rsa_bits  = "2048"

}

resource "tls_cert_request" "proxy" {

  key_algorithm   = "RSA"
  private_key_pem = "${tls_private_key.proxy.private_key_pem}"

  subject {
    country             = "US"
    organization        = "system:node-proxier"
    organizational_unit = "Kubernetes proxy"
    common_name         = "system:kube-proxy"
  }

}

resource "tls_locally_signed_cert" "proxy" {

  cert_request_pem   = "${tls_cert_request.proxy.cert_request_pem}"
  ca_key_algorithm   = "RSA"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  validity_period_hours = 87600

  allowed_uses = [
    "client_auth"
  ]

}

resource "tls_private_key" "admin" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "admin" {
  key_algorithm   = "RSA"
  private_key_pem = "${tls_private_key.admin.private_key_pem}"

  subject {
    country             = "US"
    organization        = "system:masters"
    organizational_unit = "Kubernetes Administrator"
    common_name         = "kubernetes-administrative-key"
  }
}

resource "tls_locally_signed_cert" "admin" {
  cert_request_pem   = "${tls_cert_request.admin.cert_request_pem}"
  ca_key_algorithm   = "RSA"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  validity_period_hours = 87600

  allowed_uses = [
    "client_auth"
  ]

}
