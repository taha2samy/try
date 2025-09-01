resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# --- Subnets ---
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 0)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${var.project_name}-private-subnet" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-subnet-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 2)
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-subnet-b" }
}

resource "aws_subnet" "public_d" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 3)
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-subnet-d" }
}

resource "aws_subnet" "endpoint_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 4)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${var.project_name}-endpoint-subnet-a" }
}

# --- Route Tables (THE FINAL CORRECT VERSION) ---

# 1. Private Route Table (For Workloads) - Sends all traffic TO the Endpoint
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = aws_vpc_endpoint.main.id
  }
  tags       = { Name = "${var.project_name}-private-rt" }
  depends_on = [aws_vpc_endpoint.main]
}

# 2. Public Route Table (For NAT Appliances) - THE CRITICAL FIX IS HERE
resource "aws_route_table" "public_nat" {
  vpc_id = aws_vpc.main.id

  # Route 1: For outbound traffic to the Internet
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  # Route 2: THE MISSING PIECE. For return traffic back to the Workloads, send it via the Endpoint.
  route {
    cidr_block      = aws_subnet.private.cidr_block
    vpc_endpoint_id = aws_vpc_endpoint.main.id
  }

  tags       = { Name = "${var.project_name}-public-nat-rt" }
  depends_on = [aws_vpc_endpoint.main]
}

# 3. Endpoint Route Table (For GWLB Endpoint) - Sends traffic TO the Internet
resource "aws_route_table" "endpoint" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project_name}-endpoint-rt" }
}

# 4. Jumpbox Route Table
resource "aws_route_table" "public_jumbox" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project_name}-public-jumpbox-rt" }
}

# --- Route Table Associations ---

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_nat.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_nat.id
}

resource "aws_route_table_association" "endpoint_a" {
  subnet_id      = aws_subnet.endpoint_a.id
  route_table_id = aws_route_table.endpoint.id
}

resource "aws_route_table_association" "public_d" {
  subnet_id      = aws_subnet.public_d.id
  route_table_id = aws_route_table.public_jumbox.id
}
resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.main.id

  # --- Ingress (Inbound) Rules ---
  
  # Allow all inbound traffic
  ingress {
    protocol   = "-1"  # "-1" means all protocols
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # --- Egress (Outbound) Rules ---

  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.project_name}-main-nacl"
  }
}

# --- Associate the NACL with all subnets ---

resource "aws_network_acl_association" "private_workload" {
  network_acl_id = aws_network_acl.main.id
  subnet_id      = aws_subnet.private.id
}

resource "aws_network_acl_association" "public_appliance_a" {
  network_acl_id = aws_network_acl.main.id
  subnet_id      = aws_subnet.public_a.id
}

resource "aws_network_acl_association" "public_appliance_b" {
  network_acl_id = aws_network_acl.main.id
  subnet_id      = aws_subnet.public_b.id
}

resource "aws_network_acl_association" "public_jumpbox" {
  network_acl_id = aws_network_acl.main.id
  subnet_id      = aws_subnet.public_d.id
}

resource "aws_network_acl_association" "gwlb_endpoint_a" {
  network_acl_id = aws_network_acl.main.id
  subnet_id      = aws_subnet.endpoint_a.id
}