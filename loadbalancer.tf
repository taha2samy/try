
resource "aws_lb" "main" {
  name                             = "${var.project_name}-gwlb"
  load_balancer_type               = "gateway"
  subnets                          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true
  tags = {
    Name = "${var.project_name}-gwlb"
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 6081
  protocol = "GENEVE"
  vpc_id   = aws_vpc.main.id
  health_check {
    protocol = "TCP"
    port     = "80"
  }
}

resource "aws_vpc_endpoint_service" "main" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.main.arn]

  tags = {
    Name = "${var.project_name}-gwlb-service"
  }
}

resource "aws_vpc_endpoint" "main" {
  vpc_id            = aws_vpc.main.id
  service_name      = aws_vpc_endpoint_service.main.service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = [aws_subnet.endpoint_a.id]
  tags = {
    Name = "${var.project_name}-gwlb-endpoint"
  }
}


