# Partial label — only the fields that are set are emitted; the rest are omitted.

run "namespace_level_partial" {
  command = plan

  variables {
    namespace   = "cnct"
    region      = "uk"
    stage       = "prd"
    application = "mobile"
    # no module, stack_suffix, or name
  }

  assert {
    condition     = output.id == "cnct-uk-prd-mobile"
    error_message = "a nameless label composes the hierarchy: <namespace>-<region>-<stage>-<application>, got ${output.id}"
  }
  assert {
    condition     = output.tags["ohi:application"] == "mobile"
    error_message = "set hierarchy tag should be present"
  }
  assert {
    condition     = output.tags["Stage"] == "prd"
    error_message = "Stage tag should be present"
  }
  assert {
    condition     = !contains(keys(output.tags), "ohi:module")
    error_message = "unset module tag should be omitted"
  }
  assert {
    condition     = output.tags["ohi:stack-name"] == "cnct-uk-prd-mobile"
    error_message = "ohi:stack-name derives from the deepest set hierarchy (here application), got ${output.tags["ohi:stack-name"]}"
  }
  assert {
    condition     = !contains(keys(output.tags), "ohi:owner")
    error_message = "unset owner should be omitted"
  }
}

run "only_namespace" {
  command = plan

  variables {
    namespace = "cnct"
    # no region/stage, no name
  }

  assert {
    condition     = output.id == "cnct"
    error_message = "with only a namespace and no name, the id is just the namespace (cnct), got ${output.id}"
  }
  assert {
    condition     = output.tags["Namespace"] == "cnct"
    error_message = "Namespace tag should be present"
  }
  assert {
    condition     = output.tags["Name"] == "cnct"
    error_message = "Name should equal the id (cnct)"
  }
  assert {
    condition     = !contains(keys(output.tags), "ohi:stack-name")
    error_message = "with no application/module hierarchy, ohi:stack-name should be omitted"
  }
}

run "disabled" {
  command = plan

  variables {
    enabled   = false
    namespace = "cnct"
    region    = "uk"
    stage     = "prd"
    name      = "api"
  }

  assert {
    condition     = output.id == ""
    error_message = "a disabled label should produce an empty id"
  }
  assert {
    condition     = length(output.tags) == 0
    error_message = "a disabled label should produce no tags"
  }
}
