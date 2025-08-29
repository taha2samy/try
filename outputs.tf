resource "local_file" "jump_box_connection_command" {
  filename = "1_connect_to_jumpbox.txt"
  content  = "ssh -i \"${aws_key_pair.ec2_key.key_name}.pem\" ec2-user@${aws_instance.jump_box.public_ip}"
}

resource "local_file" "workload_connection_command" {
  filename = "2_connect_to_workload_via_tunnel.txt"
  content  = "ssh -i \"${aws_key_pair.ec2_key.key_name}.pem\" -o ProxyCommand=\"ssh -W %h:%p -i '${aws_key_pair.ec2_key.key_name}.pem' ec2-user@${aws_instance.jump_box.public_ip}\" ec2-user@${aws_instance.workload.private_ip}"
}

output "jump_box_ssh_command" {
  description = "Command to connect to the Jump Box."
  value       = "ssh -i \"${aws_key_pair.ec2_key.key_name}.pem\" ec2-user@${aws_instance.jump_box.public_ip}"
}

output "workload_ssh_command" {
  description = "Command to connect to the Workload instance via the Jump Box tunnel."
  value       = "ssh -i \"${aws_key_pair.ec2_key.key_name}.pem\" -o ProxyCommand=\"ssh -W %h:%p -i '${aws_key_pair.ec2_key.key_name}.pem' ec2-user@${aws_instance.jump_box.public_ip}\" ec2-user@${aws_instance.workload.private_ip}"
}

data "aws_network_interface" "gwlbe_eni" {
  for_each = toset(aws_vpc_endpoint.main.network_interface_ids)
  id       = each.key
}

# Output the private IPs of the Gateway Load Balancer Endpoint
output "gateway_load_balancer_endpoint_ips" {
  description = "The private IP addresses of the Gateway Load Balancer VPC Endpoint network interfaces."
  value       = [for ni in data.aws_network_interface.gwlbe_eni : ni.private_ip]
}