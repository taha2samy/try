resource "aws_iam_role" "nat_role" {
  name = "${var.project_name}-nat-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action   = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "nat_policy" {
  name = "${var.project_name}-nat-policy"
  role = aws_iam_role.nat_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "ec2:ModifyInstanceAttribute",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "nat_profile" {
  name = "${var.project_name}-nat-profile"
  role = aws_iam_role.nat_role.name
}
