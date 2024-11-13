variable "availability_zone" {
  type    = string
  default = "us-east-1"
}


variable "ec2_ami_id" {
  type    = string
  default = "ami-063d43db0594b521b"
}

variable "iam_profile" {
  type    = string
  default = "LabInstanceProfile"
}

variable "number_ec2" {
  type    = number
  default = 2
}