terraform {
  required_version = ">= 1.3.0"
}

# Root label for the vlt-mobile backend in us / stg.
module "label" {
  source = "../../"

  country           = "us"
  stage             = "stg"
  deployment_region = "usw2"

  project     = "vlt"
  application = "mobile"            # -> ohi:application = vlt-mobile
  module      = "be"                # -> ohi:module = vlt-mobile-be, ohi:stack-name = usstg-usw2-vlt-mobile-be
  owner       = "vlt-mobile-circle" # -> ohi:owner = vlt-mobile-circle

  tags = {
    Team = "voltron"
  }
}

# Child label: inherits the root context (project/application), sets only the
# leaf name + attribute. id composes the hierarchy -> usstg-usw2-vlt-mobile-api-v1.
module "api_label" {
  source = "../../"

  context    = module.label.context
  name       = "api"
  attributes = ["v1"]
}

# Non-prod shared resource: same context, but non_prd swaps the stage
# segment. id -> usnp-usw2-vlt-mobile-shared.
module "shared_nonprd_label" {
  source = "../../"

  context = module.label.context
  non_prd = true
  name    = "shared"
}

# Unprefixed tag keys: tag_prefix = "" yields project/application/… instead of ohi:*.
module "bare_label" {
  source = "../../"

  context    = module.label.context
  tag_prefix = ""
  name       = "api"
}

# Length-limited id: a long composed id is truncated to 24 chars with a trailing hash.
module "truncated_label" {
  source = "../../"

  context         = module.label.context
  name            = "api-with-a-very-long-leaf-name"
  id_length_limit = 24
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

output "truncated" {
  value = { id = module.truncated_label.id, id_full = module.truncated_label.id_full, tags = module.truncated_label.tags }
}
