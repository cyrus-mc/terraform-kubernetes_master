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

  name   = "Kubernetes-S3.${var.name}"
  path   = "/"
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

  name   = "Kubernetes-ELB.${var.name}"
  path   = "/"
  policy = "${data.aws_iam_policy_document.kubernetes-elb.json}"

  lifecycle {
    create_before_destroy = true
  }

}

data "aws_iam_policy_document" "kubernetes-snapshots" {

  statement {
    actions = [
      "ec2:CreateSnapshot",
      "ec2:DeleteSnapshot",
      "ec2:ModifySnapshotAttribute",
      "ec2:ResetSnapshotAttribute"
    ]

    resources = [
      "*"
    ]
  }

}

resource "aws_iam_policy" "kubernetes-snapshots" {

  name   = "Kubernetes-Snapshots.${var.name}"
  path   = "/"
  policy = "${data.aws_iam_policy_document.kubernetes-snapshots.json}"

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

  name   = "Kubernetes-EC2.${var.name}"
  path   = "/"
  policy = "${data.aws_iam_policy_document.kubernetes-ec2.json}"

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_iam_role" "kubernetes" {

  name = "Kubernetes.${var.name}"

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

resource "aws_iam_instance_profile" "kubernetes" {

  name = "Kubernetes.${var.name}"
  role = "${aws_iam_role.kubernetes.name}"

}

/*
  Attach policies to above role
*/
resource "aws_iam_role_policy_attachment" "kubernetes-ec2" {
  role       = "${aws_iam_role.kubernetes.name}"
  policy_arn = "${aws_iam_policy.kubernetes-ec2.arn}"
}

resource "aws_iam_role_policy_attachment" "kubernetes-elb" {
  role       = "${aws_iam_role.kubernetes.name}"
  policy_arn = "${aws_iam_policy.kubernetes-elb.arn}"
}

resource "aws_iam_role_policy_attachment" "kubernetes-s3" {
  role       = "${aws_iam_role.kubernetes.name}"
  policy_arn = "${aws_iam_policy.kubernetes-s3.arn}"
}
