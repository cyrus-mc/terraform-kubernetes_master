{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:AssumeRole"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
         "ec2:DescribeVolumes",
         "ec2:DescribeTags",
         "ec2:CreateTags",
         "ec2:DescribeInstances"
      ],
      "Resource": "*"
    }
  ]
}
