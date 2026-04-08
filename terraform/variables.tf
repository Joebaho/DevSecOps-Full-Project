variable "aws_region" {
  description = "AWS region where resources will be provisioned"
  default     = "us-west-2"
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  default     = "t3.large"
}
