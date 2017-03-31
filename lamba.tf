/*
  Lambda function used to generate certificates for use in a Kubernetes cluster

  Dependencies: aws_iam_role.kubernetes-lambda
*/

resource "aws_lambda_function" "certificates" {
  filename         = "${path.module}/generate.zip"
  runtime          = "python2.7"
  function_name    = "k8s-cluster-certs"
  role             = "${aws_iam_role.kubernetes-lambda.arn}"
  handler          = "generate.lambda_handler"
	timeout					 = "30"
  source_code_hash = "${base64sha256(file("${path.module}/generate.zip"))}"
}

/* can we use a local exec provisioner to check out GitHub repo and compile generate.zip? */
