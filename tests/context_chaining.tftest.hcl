# Partial label with context passed on and sub-labels extending — mirrors the
# Luscii org -> workload -> resource label chain, OMRON-style. Uses the harness
# module in ./tests/chain, which instantiates the label module three times.

run "org_to_workload_to_resource" {
  command = plan

  module {
    source = "./tests/chain"
  }

  # Org level is partial (no name) -> id is just the prefix.
  assert {
    condition     = output.org_id == "usstg-usw2"
    error_message = "org label id should be the prefix, got ${output.org_id}"
  }

  # Workload inherits prefix + project/application from context and adds module + name.
  assert {
    condition     = output.workload_id == "usstg-usw2-vlt-mobile-api"
    error_message = "workload id should extend the prefix with the name, got ${output.workload_id}"
  }
  assert {
    condition     = output.workload_tags["ohi:project"] == "vlt" && output.workload_tags["ohi:application"] == "vlt-mobile"
    error_message = "workload should inherit ohi:project/application from context"
  }
  assert {
    condition     = output.workload_tags["ohi:module"] == "vlt-mobile-be"
    error_message = "workload should set its own ohi:module"
  }
  assert {
    condition     = output.workload_tags["Team"] == "voltron"
    error_message = "workload should inherit the user tag (Team) from context"
  }
  assert {
    condition     = output.workload_tags["ohi:owner"] == "vlt-mobile-circle"
    error_message = "workload should inherit ohi:owner from context"
  }
  assert {
    condition     = output.workload_tags["Name"] == "usstg-usw2-vlt-mobile-api"
    error_message = "workload Name should be recomputed to its own id"
  }

  # Resource inherits the name (via context) and appends the attribute.
  assert {
    condition     = output.resource_id == "usstg-usw2-vlt-mobile-api-v1"
    error_message = "resource id should extend the inherited name with the attribute, got ${output.resource_id}"
  }
  assert {
    condition     = output.resource_tags["ohi:module"] == "vlt-mobile-be"
    error_message = "resource should inherit ohi:module through the chain"
  }
  assert {
    condition     = output.resource_tags["ohi:owner"] == "vlt-mobile-circle"
    error_message = "resource should inherit ohi:owner through the chain"
  }
}
