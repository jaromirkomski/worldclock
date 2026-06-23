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
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "worldclock" {
  vpc_id                  = aws_vpc.worldclock.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
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

resource "aws_route_table_association" "worldclock" {
  subnet_id      = aws_subnet.worldclock.id
  route_table_id = aws_route_table.worldclock.id
}

# Security Group
resource "aws_security_group" "worldclock" {
  vpc_id = aws_vpc.worldclock.id

  ingress {
    from_port   = 3000
    to_port     = 3000
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
    subnets          = [aws_subnet.worldclock.id]
    security_groups  = [aws_security_group.worldclock.id]
    assign_public_ip = true
  }
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.worldclock.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.worldclock.repository_url
}
