terraform {
    required_version = ">= 1.0.0, < 2.0.0"

    required_providers {
    aws = {
        source  = "hashicorp/aws"
        version = "~> 4.0"
    }
}
}
resource "aws_launch_template" "example"{
    name = "my-launch-template"
    description = "My launch template"
    image_id = "ami-04dfd853d88e818e8"
    instance_type = var.instance_type
    key_name = aws_key_pair.test_key.key_name
    vpc_security_group_ids = [aws_security_group.instance.id]
    
    user_data = base64encode(templatefile ("${path.module}/user-data.tfpl",{
        server_port = var.server_port
        db_address = data.terraform_remote_state.db.outputs.address
        db_port = data.terraform_remote_state.db.outputs.port  
    }))
}


resource "aws_autoscaling_group" "example" {
    vpc_zone_identifier = data.aws_subnets.default.ids
    target_group_arns = [aws_lb_target_group.asg.arn]
    #ELB checks instance helath in more robust way
    # Default check type is "EC2"
    health_check_type = "ELB"
    min_size = var.min_size
    max_size = var.max_size
    #desired_capacity = 2

    launch_template {
    id= aws_launch_template.example.id
    version = aws_launch_template.example.latest_version
    }

    tag {
        key = "Name"
        value ="${var.cluster_name}"
        propagate_at_launch = true
    }
}


resource "aws_key_pair" "test_key" {
  key_name   = "test_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAqijjKW0GCpgp1zzFlPeWi5R+LUJ8wiKxLTd+dkV+eoROEplWHCmnVOo8u8rpyQQFUn7dg7Tsz5YaHRCeKCAEeFFZsX/siOirp8/ujm+TWCfgfEXcveKIVBtZeKvvYca+gGhIBK3cfg6hPnY+TN2RWp+g1stSnY5PnEVy9LFScyLaaLV6s7WdxWlzaEG43EEyND8C+EysxF/sT1FmHL4ILxRzxcVIBqoiGmR3GCBvynvPHuYdp4sCvXLwXOqSMtYaTEWDn3j8Jov2EdUw3tJxuEJ7mLnJ0jCq6dRCfxyOtxDrPP2UpAF6mYn25lHBBghR31x8BrIgBWW6IVS0tLvORQ=="
}

resource "aws_security_group" "instance" {
name = "${var.cluster_name}-instance"
ingress {
from_port = var.server_port
to_port = var.server_port
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
}



resource "aws_security_group" "alb" {
    name = "${var.cluster_name}-alb"
}
resource "aws_security_group_rule" "allow_http_inbound" {
    type = "ingress"
    security_group_id = aws_security_group.alb.id

    from_port = local.http_port
    to_port = local.http_port
    protocol = local.tcp_protocol
    cidr_blocks = local.all_ips
}
resource "aws_security_group_rule" "allow_all_outbound" {
    type = "egress"
    security_group_id = aws_security_group.alb.id

    from_port = local.any_port
    to_port = local.any_port
    #any protocol
    protocol = local.any_protocol
     cidr_blocks = local.all_ips
}


resource "aws_lb" "example" {
    name = "${var.cluster_name}"
    load_balancer_type = "application"
    subnets = data.aws_subnets.default.ids
    security_groups = [aws_security_group.alb.id]
}


resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn
    port = local.http_port
    protocol = "HTTP"


    default_action {
        type = "fixed-response"

        fixed_response {
            content_type = "text/plain"
            message_body = "404: page not found"
            status_code  = "404"
    }
    }
}


#Create a target group for ASG
# Target group will health check instances
resource "aws_lb_target_group" "asg"{
    name = "terraform-asg-example"
    port = var.server_port
    protocol ="HTTP"
    vpc_id =  data.aws_vpc.default.id

    health_check { 
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold= 2
        unhealthy_threshold = 2
    }
}


resource "aws_lb_listener_rule" "asg" {
    #Required - attaching rule to LB
    listener_arn = aws_lb_listener.http.arn
    priority = 100

    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn

    }
    
    condition {
        path_pattern {
            values = ["*"]
        }
        
    }
}



data "terraform_remote_state" "db" {
    backend = "s3"
    config = {
        bucket = var.db_remote_state_bucket
        key = var.db_remote_state_key
        region = "eu-central-1"
    }
}

locals {
    http_port = 80
    any_port = 0
    any_protocol = "-1"
    tcp_protocol = "tcp"
    all_ips = ["0.0.0.0/0"]
}





#data sources are typically search filters that indicate to the data source
#waht information you're looking for
data "aws_vpc" "default"{
    #directs Terraform to look up the Default VPC in AWS
    default = true
}
#lookup the subnets based on the vpc id
data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}


