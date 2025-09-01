resource "aws_security_group" "nat_appliance" {
  name   = "${var.project_name}-nat-appliance-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    protocol = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [aws_vpc.main.cidr_block]
  }



  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-nat-appliance-sg"
  }
}

resource "aws_security_group" "ssh" {
  name   = "${var.project_name}-ssh-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "${var.project_name}-ssh-sg"
  }
}

resource "aws_instance" "jump_box" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_d.id
  key_name               = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.ssh.id]
  tags = {
    Name = "${var.project_name}-ssh-instance"
  }
}

resource "aws_launch_template" "nat_appliance" {
  name_prefix   = "${var.project_name}-nat-ec2"
  image_id      = data.aws_ami.amazon_linux2.id
  instance_type = "t3.medium"
  key_name      = aws_key_pair.ec2_key.key_name
  iam_instance_profile {
    name = aws_iam_instance_profile.nat_profile.name
  }
  network_interfaces {
    security_groups             = [aws_security_group.nat_appliance.id]
    associate_public_ip_address = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-nat-appliance"
    }
  }

  user_data = base64encode(file("${path.module}/scripts/install_gwlbtun.sh"))

}

resource "aws_autoscaling_group" "nat_appliance" {
  name                = "${var.project_name}-nat-asg"
  desired_capacity    = 1
  min_size            = 1
  max_size            = 4
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  target_group_arns   = [aws_lb_target_group.main.arn]


  launch_template {
    id      = aws_launch_template.nat_appliance.id
    version = "$Latest"
  }
}

resource "aws_security_group" "workload" {
  name   = "${var.project_name}-workload-sg"
  vpc_id = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-workload-sg" }
}

resource "aws_instance" "workload" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  key_name               = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.workload.id]
  tags = {
    Name = "${var.project_name}-workload-instance"
  }
}