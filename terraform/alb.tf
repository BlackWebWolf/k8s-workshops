//resource "aws_alb" "load_balancer" {
//  name            = "${var.project}-loadbalancer"
//  security_groups = ["${aws_security_group.loadbalancer.id}"]
//  subnets         = module.vpc.public_subnets
//
//}
//


resource "aws_lb" "load_balancer" {
  name               = "${var.project}-loadbalancer"
  internal           = false
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}

//resource "aws_alb_listener" "alb_https" {
//  load_balancer_arn = "${aws_lb.load_balancer.arn}"
//  port              = "6443"
//  protocol          = "TCP"
//
//  default_action {
//    type             = "forward"
//    target_group_arn = "${aws_alb_target_group.codedeploy_web_target_group.arn}"
//  }
//  depends_on = ["aws_alb.load_balancer"]
//}
resource "aws_alb_listener" "alb_https-k8s" {
  load_balancer_arn = "${aws_lb.load_balancer.arn}"
  port              = "6443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.codedeploy_web_target_group.arn}"
  }
  depends_on = ["aws_lb.load_balancer"]
}

################################################################################
resource "aws_lb_target_group" "codedeploy_web_target_group" {
  port     = "6443"
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id

  deregistration_delay = 60

  lifecycle {
    create_before_destroy = "true"
  }

 tags = local.tags
}