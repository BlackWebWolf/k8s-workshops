locals {
  tags = {
    Name        = "${var.project}-materials"
    Project     = "${var.project}"
    Environment = "${var.stage}"
    Terraform   = true
  }
}