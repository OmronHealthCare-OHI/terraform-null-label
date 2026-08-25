terraform {
  required_version = ">= 1.3.0"
}

# Root label for the mobile backend in the cnct (Connect) namespace, uk / prd.
module "label" {
  source = "../../"

  namespace  = "cnct"      # product token (Connect) -> id/Namespace
  region     = "uk"        # logical region -> Environment (uk = eu-west-2)
  stage      = "prd"       # -> Stage tag
  aws_region = "eu-west-2" # -> ohi:aws-region tag (NOT in the id)

  application = "mobile"        # -> ohi:application = mobile
  module      = "be"            # -> ohi:module = mobile-be, ohi:stack-name = cnct-uk-prd-mobile-be
  owner       = "mobile-circle" # -> ohi:owner = mobile-circle

  tags = {
    Team = "voltron"
  }
}

# Child label: inherits the root context (namespace/region/stage/application/...),
# sets only the leaf name + attribute. id -> cnct-uk-prd-mobile-api-v1.
module "api_label" {
  source = "../../"

  context    = module.label.context
  name       = "api"
  attributes = ["v1"]
}

# Non-prod shared resource: same context, but non_prd swaps the stage segment
# to "np". id -> cnct-uk-np-mobile-shared.
module "shared_nonprd_label" {
  source = "../../"

  context = module.label.context
  non_prd = true
  name    = "shared"
}

# Unprefixed OMRON tag keys: tag_prefix = "" yields application/module/… instead
# of ohi:*. CloudPosse's Namespace/Environment/Stage/Name tags are unaffected.
module "bare_label" {
  source = "../../"

  context    = module.label.context
  tag_prefix = ""
  name       = "api"
}

# Length-limited id: a long composed id is truncated with a trailing hash.
module "truncated_label" {
  source = "../../"

  context         = module.label.context
  name            = "api-with-a-very-long-leaf-name"
  id_length_limit = 24
}

output "root" {
  value = { id = module.label.id, tags = module.label.tags }
}

output "api" {
  value = { id = module.api_label.id, tags = module.api_label.tags }
}

output "shared_nonprd" {
  value = { id = module.shared_nonprd_label.id, tags = module.shared_nonprd_label.tags }
}

output "bare" {
  value = { id = module.bare_label.id, tags = module.bare_label.tags }
}

output "truncated" {
  value = { id = module.truncated_label.id, id_full = module.truncated_label.id_full, tags = module.truncated_label.tags }
}
