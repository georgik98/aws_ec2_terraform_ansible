# below we define with the variable instance_count how many servers we want to create
variable "instance_count" {
  default = 1
}

# below we define the default server names
variable "instance_tags" {
  type    = list(string)
  default = ["tf-ansible-1", "tf-ansible-2", "tf-ansible-3", "tf-ansible-4", "tf-ansible-5"]
}

# we use Ubuntu as the OS
variable "ami" {
  type    = string
  default = "ami-0faab6bdbac9486fb" #eu-central-1 image for 64-bit (x86))Ubuntu Server 22.04 LTS
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}