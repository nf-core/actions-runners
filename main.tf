locals {
  environment = var.environment != null ? var.environment : "multi-runner"
  aws_region  = "eu-central-1"

  # Load runner configurations from Yaml files
  multi_runner_config = { for c in fileset("${path.module}/runner-configs", "*.yaml") : trimsuffix(c, ".yaml") => yamldecode(file("${path.module}/runner-configs/${c}")) }
}

resource "random_id" "random" {
  byte_length = 18
}

module "runners" {
  source                            = "philips-labs/github-runner/aws//modules/multi-runner"
  version                           = "4.4.1"
  multi_runner_config               = local.multi_runner_config
  aws_region                        = local.aws_region
  vpc_id                            = module.vpc.vpc_id
  subnet_ids                        = module.vpc.private_subnets
  runners_scale_up_lambda_timeout   = 60
  runners_scale_down_lambda_timeout = 60
  prefix                            = local.environment
  tags = {
    Project = "ProjectX"
  }
  github_app = {
    key_base64     = var.github_app.key_base64
    id             = var.github_app.id
    webhook_secret = random_id.random.hex
  }

  webhook_lambda_zip                = "lambdas-download/webhook.zip"
  runner_binaries_syncer_lambda_zip = "lambdas-download/runner-binaries-syncer.zip"
  runners_lambda_zip                = "lambdas-download/runners.zip"

  # Enable debug logging for the lambda functions
  log_level = "debug"
}

module "webhook-github-app" {
  source  = "philips-labs/github-runner/aws//modules/webhook-github-app"
  version = "4.4.1"
  depends_on = [ module.runners ]

  github_app = {
    key_base64     = var.github_app.key_base64
    id             = var.github_app.id
    webhook_secret = random_id.random.hex
  }
  webhook_endpoint = module.runners.webhook.endpoint
}

output "webhook_endpoint" {
  value = module.runners.webhook.endpoint
} 
