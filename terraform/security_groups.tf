##############################################################################
# Load Balancer
resource "aws_security_group" "loadbalancer" {
  name        = "${var.project}-loadbalancer-sg"
  description = "Loadbalancer security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 6443
    to_port   = 6443
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

 tags = local.tags
}

##############################################################################
# WEB behind LB
resource "aws_security_group" "web_instances_behind_alb" {
  name        = "${var.project}-web-instances-behind-alb-sg"
  description = "${var.project} web instances - accept traffic from ALB only - security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = ["${aws_security_group.loadbalancer.id}"]
  }
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

 tags = local.tags
}
