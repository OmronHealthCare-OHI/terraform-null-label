# Harness for the context-chaining test: mirrors the Luscii
# namespace -> workload -> resource label chain, OMRON-style. Instantiates the
# label module three times, each inheriting the previous one's context.

terraform {
  required_version = ">= 1.3.0"
}

# Namespace-level root label: id segments + application + a shared tag. No name.
module "org" {
  source = "../../"

  namespace   = "cnct"
  region      = "uk"
  stage       = "prd"
  application = "mobile"
  owner       = "mobile-circle"

  tags = {
    Team = "voltron"
  }
}

# Workload sub-label: inherits the namespace context, adds module segment + leaf name.
module "workload" {
  source = "../../"

  context = module.org.context
  module  = "be"
  name    = "api" # id composes the inherited hierarchy -> cnct-uk-prd-mobile-api
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
