# Partial label — only the fields that are set are emitted; the rest are omitted.

run "org_level_partial" {
  command = plan

  variables {
    country           = "us"
    stage             = "stg"
    deployment_region = "usw2"
    project           = "vlt"
    application       = "mobile"
    # no module, stack_suffix, or name
  }

  assert {
    condition     = output.id == "usstg-usw2-vlt-mobile"
    error_message = "a nameless label composes the hierarchy: <PREFIX>-<project>-<application>, got ${output.id}"
  }
  assert {
    condition     = output.tags["ohi:project"] == "vlt" && output.tags["ohi:application"] == "vlt-mobile"
    error_message = "set hierarchy tags should be present"
  }
  assert {
    condition     = output.tags["ohi:environment"] == "usstg-usw2"
    error_message = "ohi:environment should be the prefix"
  }
  assert {
    condition     = !contains(keys(output.tags), "ohi:module") && !contains(keys(output.tags), "ohi:stack-name")
    error_message = "unset hierarchy tags should be omitted"
  }
  assert {
    condition     = !contains(keys(output.tags), "ohi:owner")
    error_message = "unset owner should be omitted"
  }
}

run "only_project" {
  command = plan

  variables {
    project = "vlt"
    # no prefix parts, no name
  }

  assert {
    condition     = output.id == "vlt"
    error_message = "with no prefix parts and no name, the id is just the hierarchy (vlt), got ${output.id}"
  }
  assert {
    condition     = output.tags["ohi:project"] == "vlt"
    error_message = "ohi:project should be present"
  }
  assert {
    condition     = output.tags["Name"] == "vlt"
    error_message = "Name should equal the id (vlt)"
  }
  assert {
    condition     = length(output.tags) == 2
    error_message = "ohi:project + Name should be emitted (no stage), got ${length(output.tags)} tags"
  }
}

run "disabled" {
  command = plan

  variables {
    enabled           = false
    country           = "us"
    stage       = "stg"
    deployment_region = "usw2"
    project           = "vlt"
    name              = "vlt-mobile-api"
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
