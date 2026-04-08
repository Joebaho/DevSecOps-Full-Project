variable "aws_region" {
  description = "AWS region where resources will be provisioned"
  default     = "us-west-2"
}

variable "instance_type" {
  description = "Instance type for the EC2 instances"
  default     = "t3.large"
}

variable "root_volume_size" {
  description = "Root volume size in GiB for the EC2 instances"
  default     = 29
}

variable "key_pair_name" {
  description = "Name of an existing AWS EC2 key pair to attach to the instances"
  default     = "ansible-key"
}
