# Harness for the propagation test: a parent label that withholds its owner
# from the context (owner_propagation_enabled = false) and disables the
# stack-name tag, with two children — one inheriting as-is, one stating its
# own owner and re-enabling the stack-name tag. The owner reset is ONE level
# deep (the toggle is not part of the context), so owned_child's owner
# propagates onward to its own children normally.

terraform {
  required_version = ">= 1.3.0"
}

# Parent: owns its resources, but does not pass its owner down.
module "parent" {
  source = "../../"

  country           = "us"
  stage             = "stg"
  deployment_region = "usw2"
  project           = "vlt"
  application       = "mobile"

  owner                     = "vlt-mobile-circle"
  owner_propagation_enabled = false
  stack_name_enabled        = false
}

# Child inheriting the parent's context untouched: no owner, no stack-name tag.
module "child" {
  source = "../../"

  context = module.parent.context
  module  = "be"
  name    = "api"
}

# Child that states its own owner and locally re-enables the stack-name tag.
module "owned_child" {
  source = "../../"

  context            = module.parent.context
  module             = "be"
  name               = "api"
  owner              = "other-circle"
  stack_name_enabled = true
}

output "parent_tags" { value = module.parent.tags }
output "child_tags" { value = module.child.tags }
output "owned_child_tags" { value = module.owned_child.tags }
output "child_context" { value = module.child.context }
output "owned_child_context" { value = module.owned_child.context }
