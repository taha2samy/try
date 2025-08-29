# ############################################################
# # CloudWatch Log Group
# ############################################################
# resource "aws_cloudwatch_log_group" "vpc_flow_logs_group" {
#   name              = "/vpc/gwlb-nat-flow-logs-${var.project_name}"
#   retention_in_days = 7
# }

# ############################################################
# # IAM Role for VPC Flow Logs
# ############################################################
# resource "aws_iam_role" "vpc_flow_logs_role" {
#   name = "vpc-flow-logs-role-${var.project_name}"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect    = "Allow",
#         Principal = { Service = "vpc-flow-logs.amazonaws.com" },
#         Action    = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# resource "aws_iam_policy" "vpc_flow_logs_policy" {
#   name = "vpc-flow-logs-policy-${var.project_name}"

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents",
#           "logs:DescribeLogGroups",
#           "logs:DescribeLogStreams"
#         ],
#         Effect   = "Allow",
#         Resource = "*"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "vpc_flow_logs_attachment" {
#   role       = aws_iam_role.vpc_flow_logs_role.name
#   policy_arn = aws_iam_policy.vpc_flow_logs_policy.arn
# }

# ############################################################
# # Workload ENI Flow Log
# ############################################################
# resource "aws_flow_log" "workload_eni_flow_log" {
#   iam_role_arn    = aws_iam_role.vpc_flow_logs_role.arn
#   log_destination = aws_cloudwatch_log_group.vpc_flow_logs_group.arn
#   traffic_type    = "ALL"
#   eni_id          = aws_instance.workload.primary_network_interface_id

#   log_format = "$${version} $${action} $${log-status} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${pkt-srcaddr} $${pkt-dstaddr}"
# }

# ############################################################
# # Data Source: NAT Appliance Instances
# ############################################################
# data "aws_instances" "nat_appliance_instances" {
#   instance_tags        = { Name = "${var.project_name}-nat-appliance" }
#   instance_state_names = ["running"]

#   depends_on = [aws_autoscaling_group.nat_appliance]
# }

# ############################################################
# # Data Source: Each NAT Instance
# ############################################################
# data "aws_instance" "nat_appliance_instance" {
#   for_each = toset(data.aws_instances.nat_appliance_instances.ids)

#   instance_id = data.aws_instances.nat_appliance_instances.ids[count.index]

#   depends_on = [data.aws_instances.nat_appliance_instances]
# }

# ############################################################
# # NAT ENI Flow Logs
# ############################################################
# resource "aws_flow_log" "nat_eni_flow_logs" {
#   for_each = toset(data.aws_instances.nat_appliance_instances.ids)


#   iam_role_arn    = aws_iam_role.vpc_flow_logs_role.arn
#   log_destination = aws_cloudwatch_log_group.vpc_flow_logs_group.arn
#   traffic_type    = "ALL"
#   eni_id          = data.aws_instance.nat_appliance_instance[count.index].primary_network_interface_id

#   depends_on = [data.aws_instances.nat_appliance_instances]
# }
