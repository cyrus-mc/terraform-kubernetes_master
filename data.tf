/*
  Query subnet details
*/
data "aws_subnet" "selected" {
  count = "${length(var.subnet_id)}"

  id = "${element(var.subnet_id, count.index)}"
}
