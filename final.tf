provider "aws" {
  region  = "us-east-1"
}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "terraform"
  }
}

resource "aws_subnet" "public-a" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "public-tf-a"
  }
}

resource "aws_subnet" "public-b" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "public-tf-b"
  }
}

resource "aws_subnet" "private-a" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "public-tf-a"
  }
}

resource "aws_subnet" "private-b" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "10.0.4.0/24"

  tags = {
    Name = "public-tf-b"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "igw-tf"
  }
}

resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public-a.id

  tags = {
    Name = "nat-gw-cesi-tf"
  }
}

resource "aws_eip" "nat" {
}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "public-cesi-tf"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.gw.id
  }
  tags = {
    Name = "private-cesi-tf"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public-a.id
  route_table_id = aws_route_table.r.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public-b.id
  route_table_id = aws_route_table.r.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.private-a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.private-b.id
  route_table_id = aws_route_table.private.id
}


resource "aws_lb_target_group" "test" {
  name     = "lb-final"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.default.id}"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_launch_configuration" "as_conf" {
  name_prefix   = "terraform-lc-example-"
  image_id      = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  user_data = file("${path.module}/postinstall.sh")
  security_groups = ["${aws_security_group.allow_http.id}"]
  key_name        = "ec2-key" 

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow http inbound traffic"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http-tf"
  }
}

resource "aws_autoscaling_group" "bar" {
  name                 = "terraform-asg-example"
  launch_configuration = "${aws_launch_configuration.as_conf.name}"
  min_size             = 1
  max_size             = 2
  target_group_arns    = ["${aws_lb_target_group.test.arn}"]
  vpc_zone_identifier  = ["${aws_subnet.public-a.id}", "${aws_subnet.public-b.id}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.allow_http.id}"]
  subnets            = ["${aws_subnet.public-a.id}", "${aws_subnet.public-b.id}"]

  tags = {
    Environment = "production"
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = "${aws_autoscaling_group.bar.id}"
  alb_target_group_arn   = "${aws_lb_target_group.test.arn}"
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = "${aws_lb.test.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.test.arn}"
  }
}

output "dns-name" {
  value = aws_lb.test.dns_name
}
