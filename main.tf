# vpc creation
resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr

  tags = {
    Name = "custom-vpc"
  }
}

# subnet 
# public subnet1
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1a"
  }
}

# public subnet2
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1b"
  }
}

# internet gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
tags={
  Name="igwTags"
}

}

# for giving access to internet gtw we need route Table

resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
tags={
  Name="routeTable1"
}
}

# now we have to attach the subnet with route table
# Association of RT for subnet1
resource "aws_route_table_association" "RTAssociation1" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.routetable.id
}

# association of RT for subnet2
resource "aws_route_table_association" "RTAssociation2" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.routetable.id
}

# Security group

resource "aws_security_group" "webSG" {
  name        = "web"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-SG"
  }
}

# creating s3 bucket

resource "aws_s3_bucket" "s3bucket" {
    bucket = "sanjaysahmybucket"
}

resource "aws_network_interface" "mynetworkinterface"{
    subnet_id=aws_route_table_association.RTAssociation1.id
    security_groups=[aws_security_group.webSG.id]
    private_ips = ["10.0.0.10"]
    tags={
      Name="myinternetid"
    }
}

resource "aws_instance" "awsinstance1" {
    ami = "ami-0f5ee92e2d63afc18"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.webSG.id]
    subnet_id = aws_subnet.subnet1.id
    user_data = base64encode(file("userdata.sh"))
}
resource "aws_instance" "awsinstance2" {
    ami = "ami-0f5ee92e2d63afc18"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.webSG.id]
    subnet_id = aws_subnet.subnet2.id
    user_data = base64encode(file("userdata1.sh"))
}

# Load Balancers

resource "aws_lb" "public-LB" {
    name               = "myalb"
    internal           = false   # ie public lb
    load_balancer_type = "application"

    security_groups = [aws_security_group.webSG.id]
    subnets = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

    tags = {
    Name = "web"
  }
}

# target group to target of aur instance
resource "aws_lb_target_group" "LB-targetGP" {
  name     = "myTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

# attach instance to target group
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.LB-targetGP.arn
  target_id        = aws_instance.awsinstance1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.LB-targetGP.arn
  target_id        = aws_instance.awsinstance2.id
  port             = 80
}

# listner 
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.public-LB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.LB-targetGP.arn
    type             = "forward"
  }
}

# to find out dns name of the application
output "loadbalancerdns" {
  value = aws_lb.public-LB.dns_name
}




