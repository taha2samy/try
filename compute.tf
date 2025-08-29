resource "aws_security_group" "nat_appliance" {
  name   = "${var.project_name}-nat-appliance-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    protocol    = "udp"
    from_port   = 6081
    to_port     = 6081
    cidr_blocks = ["0.0.0.0/0"]
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

# FILE: ./compute.tf

resource "aws_launch_template" "nat_appliance" {
  name_prefix   = "${var.project_name}-nat-just-nat-ec2"
  image_id      = data.aws_ami.amazon_linux2.id
  instance_type = "t3.micro"
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
  user_data =  base64encode(<<-EOF
  #!/bin/bash
  set -e -x
  
  yum update -y
  yum install -y awscli iptables-services

  INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
  aws ec2 modify-instance-attribute \
    --instance-id $INSTANCE_ID \
    --no-source-dest-check \
    --region $REGION

  echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  sysctl -p

  modprobe geneve
  ip link add geneve0 type geneve id 0 remote 0.0.0.0 dstport 6081
  ip link set geneve0 up

  PRIMARY_INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
  iptables -t nat -A POSTROUTING -o $PRIMARY_INTERFACE -j MASQUERADE
  iptables -A FORWARD -i geneve0 -j ACCEPT
  iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

  service iptables save
  systemctl enable iptables
  systemctl start iptables
EOF
  )

}
resource "aws_autoscaling_group" "nat_appliance" {
  name                = "${var.project_name}-nat-asg"
  desired_capacity    = 3
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