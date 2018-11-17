provider aws {
  profile = "dev"
  region  = "us-west-2"
}

data "template_file" "stub" {
  template = ""

  vars {}
}
