
variable "project" {
  description = "Project name"
  default     = "k8s-workshops"
}

variable "stage" {
  description = "Project stage"
  default     = "prod"
}

variable "region" {
  description = "AWS Region"
  default     = "eu-central-1"
}

//variable "domain" {
//  description = "Base domain for the project"
//  default     = "app.gotickety.com"
//}

variable "asg_instance_type" {
  description = "EC2 instance type, e.g. t3.small"
  default     = "t3.small"
}
