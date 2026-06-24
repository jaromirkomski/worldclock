terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# ECR
resource "aws_ecr_repository" "worldclock" {
  name = "worldclock"
}

# ECS Cluster
resource "aws_ecs_cluster" "worldclock" {
  name = "worldclock"
}

# IAM Role dla ECS
resource "aws_iam_role" "ecs_task_execution" {
  name = "worldclock-ecs-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# VPC
resource "aws_vpc" "worldclock" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

# Subnet 1 (us-east-1a)
resource "aws_subnet" "worldclock_a" {
  vpc_id                  = aws_vpc.worldclock.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

# Subnet 2 (us-east-1b) - wymagany przez ALB
resource "aws_subnet" "worldclock_b" {
  vpc_id                  = aws_vpc.worldclock.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "worldclock" {
  vpc_id = aws_vpc.worldclock.id
}

resource "aws_route_table" "worldclock" {
  vpc_id = aws_vpc.worldclock.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.worldclock.id
  }
}

resource "aws_route_table_association" "worldclock_a" {
  subnet_id      = aws_subnet.worldclock_a.id
  route_table_id = aws_route_table.worldclock.id
}

resource "aws_route_table_association" "worldclock_b" {
  subnet_id      = aws_subnet.worldclock_b.id
  route_table_id = aws_route_table.worldclock.id
}

# Security Group dla ALB
resource "aws_security_group" "alb" {
  vpc_id = aws_vpc.worldclock.id

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
}

# Security Group dla ECS - tylko ruch z ALB
resource "aws_security_group" "ecs" {
  vpc_id = aws_vpc.worldclock.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB
resource "aws_lb" "worldclock" {
  name               = "worldclock"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.worldclock_a.id, aws_subnet.worldclock_b.id]
}

# Target Group
resource "aws_lb_target_group" "worldclock" {
  name        = "worldclock"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.worldclock.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

# ALB Listener
resource "aws_lb_listener" "worldclock" {
  load_balancer_arn = aws_lb.worldclock.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.worldclock.arn
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "worldclock" {
  family                   = "worldclock"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = "worldclock"
    image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/worldclock:latest"
    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/worldclock"
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "worldclock" {
  name = "/ecs/worldclock"
}

# ECS Service
resource "aws_ecs_service" "worldclock" {
  name            = "worldclock"
  cluster         = aws_ecs_cluster.worldclock.id
  task_definition = aws_ecs_task_definition.worldclock.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.worldclock_a.id, aws_subnet.worldclock_b.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.worldclock.arn
    container_name   = "worldclock"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.worldclock]
}

output "alb_dns_name" {
  value = aws_lb.worldclock.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.worldclock.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.worldclock.name
}
