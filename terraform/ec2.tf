resource "aws_instance" "masters" {
  count = 3
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"

 tags = merge(
         local.tags,
          {
            Name = format("controller-%d", count.index)
          }
          )
  vpc_security_group_ids = [aws_security_group.web_instances_behind_alb.id]
  associate_public_ip_address = true
  private_ip = format("10.0.101.%d", count.index+10)
  source_dest_check = false
  subnet_id = module.vpc.public_subnets[0]
  key_name = "mkajszczak-key"
}

resource "aws_instance" "workers" {
  count = 1
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"

 tags = merge(
          local.tags,
          {
            Name = format("worker-%d", count.index)
          }
         )
  vpc_security_group_ids = [aws_security_group.web_instances_behind_alb.id]
  associate_public_ip_address = true
  private_ip = format("10.0.102.%d", count.index+20)
  source_dest_check = false
  subnet_id = module.vpc.public_subnets[1]
  key_name = "mkajszczak-key"


}

resource "aws_lb_target_group_attachment" "test" {
  count = 3
  target_group_arn = "${aws_lb_target_group.codedeploy_web_target_group.arn}"
  target_id        = "${aws_instance.masters[count.index].id}"
  port             = 6443
}