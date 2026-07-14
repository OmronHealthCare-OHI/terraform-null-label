# Harness for the context-chaining test: mirrors the Luscii
# org -> workload -> resource label chain, OMRON-style. Instantiates the
# label module three times, each inheriting the previous one's context.

terraform {
  required_version = ">= 1.3.0"
}

# Org-level root label: prefix parts + project/application + a shared tag. No name.
module "org" {
  source = "../../"

  country           = "us"
  environment       = "stg"
  deployment_region = "usw2"
  project           = "vlt"
  application       = "mobile"

  tags = {
    Team = "voltron"
  }
}

# Workload sub-label: inherits the org context, adds module segment + name.
module "workload" {
  source = "../../"

  context = module.org.context
  module  = "be"
  name    = "vlt-mobile-api"
}

# Resource sub-label: extends the workload context with an attribute only.
module "resource" {
  source = "../../"

  context    = module.workload.context
  attributes = ["v1"]
}

output "org_id" { value = module.org.id }
output "org_tags" { value = module.org.tags }
output "workload_id" { value = module.workload.id }
output "workload_tags" { value = module.workload.tags }
output "resource_id" { value = module.resource.id }
output "resource_tags" { value = module.resource.tags }
