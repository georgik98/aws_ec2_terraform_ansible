provider "aws" {
  alias  = "eu"
  region = "eu-central-1"
}

data "aws_region" "current" {}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "AWS VPC"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "main" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "${data.aws_region.current.name}a"
}

resource "aws_subnet" "new" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${data.aws_region.current.name}b"
}

resource "aws_subnet" "jenkins" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${data.aws_region.current.name}c"
}

resource "aws_route_table_association" "route_table_association-2" {
  subnet_id      = aws_subnet.new.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table_association" "route_table_association-3" {
  subnet_id      = aws_subnet.jenkins.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.route_table.id
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "aws_key" {
  key_name   = "ansible-ssh-key"
  public_key = tls_private_key.key.public_key_openssh
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH traffic"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
}


resource "aws_security_group" "allow_jenkins" {
  name        = "allow_jenkins"
  description = "Allow 8080 traffic"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
}

resource "aws_instance" "server" {
  count                       = var.instance_count
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.aws_key.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.main.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id, aws_security_group.allow_http.id]

  tags = {
    Name = element(var.instance_tags, count.index)
  }
}

resource "aws_instance" "instance" {
  count                       = var.instance_count
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.aws_key.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.new.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id, aws_security_group.allow_http.id]

  tags = {
    Name = element(var.instance_tags, count.index + 1)
  }
}

resource "aws_instance" "jenkins" {
  count                       = var.instance_count
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.aws_key.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.jenkins.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id, aws_security_group.allow_http.id, aws_security_group.allow_jenkins.id]

  tags = {
    Name = element(var.jenkins-tag, count.index)
  }
}

resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_ssh.id, aws_security_group.allow_http.id, aws_security_group.allow_jenkins.id]
  subnets            = [aws_subnet.main.id, aws_subnet.new.id, aws_subnet.jenkins.id] // at least 2 in 2 different azs

  tags = {
    Environment = "dev"
  }
}

resource "aws_lb_listener" "my_alb_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn
  }
}


resource "aws_lb_target_group" "my_tg" {
  name     = "target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "tg_attachment" {
  count            = length(aws_instance.server)
  target_group_arn = aws_lb_target_group.my_tg.arn
  target_id        = element(aws_instance.server.*.id, count.index)
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg_attachment-1" {
  count            = length(aws_instance.instance)
  target_group_arn = aws_lb_target_group.my_tg.arn
  target_id        = element(aws_instance.instance.*.id, count.index)
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg_attachment-2" {
  count            = length(aws_instance.jenkins)
  target_group_arn = aws_lb_target_group.my_tg.arn
  target_id        = element(aws_instance.jenkins.*.id, count.index)
  port             = 8080
}

resource "aws_route53_zone" "example_hosted_zone" {
  name = "jorkata111.net"
}

resource "aws_route53_record" "us-battasks" {
  zone_id = aws_route53_zone.example_hosted_zone.zone_id
  name    = "eu-battasks"
  type    = "A"
  alias {
    name                   = aws_lb.my_alb.dns_name
    zone_id                = aws_lb.my_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "dns" {
  zone_id = aws_route53_zone.example_hosted_zone.zone_id
  name    = "eu-battasks-1"
  ttl     = 30
  type    = "CNAME"
  records = [aws_lb.my_alb.dns_name]
}