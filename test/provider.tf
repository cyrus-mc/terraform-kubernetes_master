provider aws {
  profile = "dev"
  region  = "us-west-2"
}

data "template_file" "stub" {
  template = ""

  vars {}
}

data tls_public_key "stub" {
  private_key_pem = "${file("id_rsa")}"
}

resource null_resource "stub" {}
