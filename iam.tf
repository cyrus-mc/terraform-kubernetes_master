/*
  Define policies for S3, ELB and EC2 that are required for Kubernetes
  auto-provisioning capabilities
*/
data "aws_iam_policy_document" "kubernetes-s3" {
  statement {
    sid = "1"

    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::*"
    ]
  }
}

resource "aws_iam_policy" "kubernetes-s3" {

  name = "Kubernetes-S3"
  path = "/"
  policy = "${data.aws_iam_policy_document.kubernetes-s3.json}"

  lifecycle {
    create_before_destroy = true
  }

}

data "aws_iam_policy_document" "kubernetes-elb" {

  statement {
    actions = [
      "elasticloadbalancing:*",
    ]

    resources = [
      "*"
    ]
  }

}

resource "aws_iam_policy" "kubernetes-elb" {

  name = "Kubernetes-ELB"
  path = "/"
  policy = "${data.aws_iam_policy_document.kubernetes-elb.json}"

  lifecycle {
    create_before_destroy = true
  }

}

data "aws_iam_policy_document" "kubernetes-ec2" {

  statement {
    actions = [
      "ec2:*",
    ]

    resources = [
      "*"
    ]
  }

}

resource "aws_iam_policy" "kubernetes-ec2" {

  name = "Kubernetes-EC2"
  path = "/"
  policy = "${data.aws_iam_policy_document.kubernetes-ec2.json}"

  lifecycle {
    create_before_destroy = true
  }

}


/*
  Policy for Lambda function used to generate K8s cluster certificates
*/
data "aws_iam_policy_document" "kubernetes-lambda-s3" {

  statement {
    actions = [
      "s3:CreateBucket",
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "arn:aws:s3:::smarsh-k8s-*",
    ]
  }

}

resource "aws_iam_policy" "kubernetes-lambda" {

  name   = "Kubernetes-Lambda"
  path   = "/"
  policy = "${data.aws_iam_policy_document.kubernetes-lambda-s3.json}"

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_iam_instance_profile" "kubernetes" {

  name = "k8s-tf"
  roles = [ "${aws_iam_role.kubernetes.name}" ]

}

resource "aws_iam_role" "kubernetes" {

  name = "k8s-tf"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

}

resource "aws_iam_role" "kubernetes-lambda" {

  name = "k8s-lambda-tf"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "kubernetes-s3" {
  role       = "${aws_iam_role.kubernetes.name}"
  policy_arn = "${aws_iam_policy.kubernetes-s3.arn}"
}

resource "aws_iam_role_policy_attachment" "kubernetes-elb" {
  role       = "${aws_iam_role.kubernetes.name}"
  policy_arn = "${aws_iam_policy.kubernetes-elb.arn}"
}

resource "aws_iam_role_policy_attachment" "kubernetes-ec2" {
  role       = "${aws_iam_role.kubernetes.name}"
  policy_arn = "${aws_iam_policy.kubernetes-ec2.arn}"
}

resource "aws_iam_role_policy_attachment" "kubernetes-lambda" {
  role       = "${aws_iam_role.kubernetes-lambda.name}"
  policy_arn = "${aws_iam_policy.kubernetes-lambda.arn}"
}

/* output instance profile ID */
output "iam_instance_profile" {
  value = "${aws_iam_instance_profile.kubernetes.id}"
}
