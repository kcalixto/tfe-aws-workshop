terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

variable "region" {
  type    = string
  default = "sa-east-1"
}

provider "aws" {
  region              = var.region
  allowed_account_ids = ["447988592397"]
}

resource "random_pet" "base_name" {

}

variable "env" {
  type    = string
  default = "dev"
}

variable "vpc_id" {
  type = string
  // TODO get env variable here
  default = "vpc-0d7caa890333b1dd7"
}
locals {
  app_name = "${random_pet.base_name.id}-${var.env}"
}

resource "aws_ecr_repository" "app" {
  name = local.app_name
  // by default, if you destroy a tfe container it will not delete the ECR
  force_delete = true
}

resource "aws_ecs_cluster" "app" {
  name = local.app_name
}

resource "aws_cloudwatch_log_group" "app" {
  name              = local.app_name
  retention_in_days = 5
}

resource "aws_ecs_task_definition" "app" {
  // kind of a tag to handle the task definition
  family = local.app_name

  // they are the same in this case, but they should be different, since one is for task as general, an the other is for the code executing in the container task
  task_role_arn      = aws_iam_role.task.arn
  execution_role_arn = aws_iam_role.task.arn

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  cpu    = 256
  memory = 512

  container_definitions = jsonencode([
    {
      name  = "nginx"
      image = "${aws_ecr_repository.app.repository_url}:1.0.0"
      // sets that container must be up to execute this task
      essential = true

      portMappings = [
        {
          hostPort      = 80,
          containerPort = 80,
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name,
          awslogs-region        = "sa-east-1",
          awslogs-stream-prefix = local.app_name
        }
      }

      linuxParameterss = {
        add = ["NET_BIND_SERVICE"]
      }
    }
  ])
}

resource "aws_iam_role" "task" {
  name = "nginx-${local.app_name}"
  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "task" {
  name = "ecs-minimum"
  role = aws_iam_role.task.name
  policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "logs:CreateLogStream",
          "logs:PustLogEvents",
          "logs:DescribeLogStreams",
        ]
        Resource = [
          "*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
        ]
        Resource = [
          aws_ecr_repository.app.arn
        ]
      }
    ]
  })
}

resource "aws_ecs_service" "app" {
  name = local.app_name

  cluster     = aws_ecs_cluster.app.id
  launch_type = "FARGATE"

  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1

  network_configuration {
    subnets         = data.aws_subnet_ids.private.ids
    security_groups = [aws_security_group.task.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_http.arn
    container_name   = "nginx"
    container_port   = 80
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = var.vpc_id
  tags = {
    app = "true"
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id
  tags = {
    dmz = "true"
  }
}

resource "aws_security_group" "task" {
  name        = "${local.app_name}-task"
  description = "sg for ${local.app_name} ECS task"
  vpc_id      = var.vpc_id
}

resource "aws_lb" "app" {
  name               = local.app_name
  load_balancer_type = "application"
  internal           = false

  security_groups = [
    aws_security_group.lb.id
  ]

  subnets = data.aws_subnet_ids.public.ids
}

resource "aws_lb_target_group" "app_http" {
  name     = local.app_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  // ip is specif for fargate
  target_type = "ip"

  // changes the way terraform deal with the resource, making the deploy logic work
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "app_http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.app_http.arn
    type             = "forward"
  }
}

resource "aws_security_group" "lb" {
  name        = "${local.app_name}-lb"
  description = "sg for ${local.app_name}-${var.env} load balancer"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "lb_http" {
  security_group_id = aws_security_group.lb.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "egress" {
  for_each = {
    lb   = aws_security_group.lb.id
    task = aws_security_group.task.id
  }
  security_group_id = each.value
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
}

