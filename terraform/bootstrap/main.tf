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

variable "github_repo" {
  description = "owner/repo, e.g. yourname/secure-devsecops-pipeline"
  type        = string
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "pipeline" {
  name               = "github-actions-pipeline"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# Scoped permissions: only what the pipeline needs.
data "aws_iam_policy_document" "pipeline" {
  statement {
    actions = [
      "ec2:*",
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:DescribeInstanceInformation"
    ]

    resources = ["*"]
  }

  statement {
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:ListRolePolicies",
      "iam:ListInstanceProfilesForRole"
    ]

    resources = [
      "arn:aws:iam::*:role/devsecops-*",
      "arn:aws:iam::*:instance-profile/devsecops-*"
    ]
  }
}

resource "aws_iam_role_policy" "pipeline" {
  name   = "pipeline-permissions"
  role   = aws_iam_role.pipeline.id
  policy = data.aws_iam_policy_document.pipeline.json
}

output "pipeline_role_arn" {
  value = aws_iam_role.pipeline.arn
}
