# Partial label with context passed on and sub-labels extending — mirrors the
# Luscii namespace -> workload -> resource label chain, OMRON-style. Uses the
# harness module in ./tests/chain, which instantiates the label module three times.

run "namespace_to_workload_to_resource" {
  command = plan

  module {
    source = "./tests/chain"
  }

  # Namespace level is partial (no name) -> id composes the hierarchy.
  assert {
    condition     = output.org_id == "cnct-uk-prd-mobile"
    error_message = "namespace label id should compose the hierarchy, got ${output.org_id}"
  }

  # Workload inherits the namespace context and adds module + leaf name.
  assert {
    condition     = output.workload_id == "cnct-uk-prd-mobile-api"
    error_message = "workload id should be <namespace>-<region>-<stage>-<application>-<name>, got ${output.workload_id}"
  }
  assert {
    condition     = output.workload_tags["ohi:application"] == "mobile"
    error_message = "workload should inherit ohi:application from context"
  }
  assert {
    condition     = output.workload_tags["ohi:module"] == "mobile-be"
    error_message = "workload should set its own ohi:module"
  }
  assert {
    condition     = output.workload_tags["Team"] == "voltron"
    error_message = "workload should inherit the user tag (Team) from context"
  }
  assert {
    condition     = output.workload_tags["ohi:owner"] == "mobile-circle"
    error_message = "workload should inherit ohi:owner from context"
  }
  assert {
    condition     = output.workload_tags["Name"] == "cnct-uk-prd-mobile-api"
    error_message = "workload Name should be recomputed to its own id"
  }

  # Resource inherits the name (via context) and appends the attribute.
  assert {
    condition     = output.resource_id == "cnct-uk-prd-mobile-api-v1"
    error_message = "resource id should extend the inherited name with the attribute, got ${output.resource_id}"
  }
  assert {
    condition     = output.resource_tags["ohi:module"] == "mobile-be"
    error_message = "resource should inherit ohi:module through the chain"
  }
  assert {
    condition     = output.resource_tags["ohi:owner"] == "mobile-circle"
    error_message = "resource should inherit ohi:owner through the chain"
  }
}
