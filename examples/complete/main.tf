terraform {
  required_version = ">= 1.3.0"
}

# Root label for the vlt-mobile backend in us / stg.
module "label" {
  source = "../../"

  country           = "us"
  environment       = "stg"
  deployment_region = "usw2"

  project     = "vlt"
  application = "vlt-mobile"
  module      = "vlt-mobile-be"
  stackname   = "usstg-usw2-vlt-be-serverless-stack"

  tags = {
    Team = "voltron"
  }
}

# Child label: inherits the root context, only sets a resource name + attribute.
module "api_label" {
  source = "../../"

  context    = module.label.context
  name       = "vlt-mobile-api"
  attributes = ["v1"]
}

# Non-prod shared resource: same context, but non_prd swaps the environment segment.
module "shared_nonprd_label" {
  source = "../../"

  context = module.label.context
  non_prd = true
  name    = "vlt-shared"
}

# Unprefixed tag keys: tag_prefix = "" yields project/application/… instead of ohi:*.
module "bare_label" {
  source = "../../"

  context    = module.label.context
  tag_prefix = ""
  name       = "vlt-mobile-api"
}

output "root" {
  value = { id = module.label.id, prefix = module.label.prefix, tags = module.label.tags }
}

output "api" {
  value = { id = module.api_label.id, prefix = module.api_label.prefix, tags = module.api_label.tags }
}

output "shared_nonprd" {
  value = { id = module.shared_nonprd_label.id, prefix = module.shared_nonprd_label.prefix, tags = module.shared_nonprd_label.tags }
}

output "bare" {
  value = { id = module.bare_label.id, prefix = module.bare_label.prefix, tags = module.bare_label.tags }
}
