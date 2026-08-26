# Resource naming — a fully specified label produces the OMRON-standard id and
# tags. id shape: <namespace>-<region>-<stage>-<application>-<name>-<attributes>.
#
# Ported to the CloudPosse-wrapped model (2026-08-25). Run blocks removed because
# the wrapped model retired their feature:
#   - `prefix` output / `prefix_enabled`      (CloudPosse label_order replaces it)
#   - `deployment_region` derivation from aws_region (AWS region is now a tag, not
#     an id segment — logical `region` drives the id)

run "full_label" {
  command = plan

  variables {
    namespace   = "cnct"
    region      = "uk"
    stage       = "prd"
    aws_region  = "eu-west-2"
    application = "mobile"
    module      = "be"
    owner       = "mobile-circle"
    name        = "api"
    attributes  = ["v1"]
  }

  assert {
    condition     = output.id == "cnct-uk-prd-mobile-api-v1"
    error_message = "id should be <namespace>-<region>-<stage>-<application>-<name>-<attributes>, got ${output.id}"
  }
  assert {
    condition     = output.tags["Namespace"] == "cnct"
    error_message = "Namespace tag should be the product token"
  }
  assert {
    condition     = output.tags["Environment"] == "uk"
    error_message = "Environment tag should be the logical region"
  }
  assert {
    condition     = output.tags["Stage"] == "prd"
    error_message = "Stage tag should be a first-class queryable tag"
  }
  assert {
    condition     = output.tags["ohi:application"] == "mobile"
    error_message = "ohi:application tag mismatch"
  }
  assert {
    condition     = output.tags["ohi:module"] == "mobile-be"
    error_message = "ohi:module tag mismatch"
  }
  assert {
    condition     = output.tags["ohi:stack-name"] == "cnct-uk-prd-mobile-be"
    error_message = "ohi:stack-name should derive to <namespace>-<region>-<stage>-<ohi:module>, got ${output.tags["ohi:stack-name"]}"
  }
  assert {
    condition     = output.tags["ohi:aws-region"] == "eu-west-2"
    error_message = "ohi:aws-region tag should equal the aws_region input"
  }
  assert {
    condition     = !contains(keys(output.tags), "ohi:environment")
    error_message = "ohi:environment is retired — CloudPosse Environment + Stage replace it"
  }
  assert {
    condition     = !contains(keys(output.tags), "ohi:project")
    error_message = "ohi:project is retired — namespace is the product identity"
  }
  assert {
    condition     = output.tags["ohi:owner"] == "mobile-circle"
    error_message = "ohi:owner tag should equal the owner input"
  }
  assert {
    condition     = output.tags["Name"] == "cnct-uk-prd-mobile-api-v1"
    error_message = "Name tag should equal the id"
  }
  assert {
    condition     = !contains(keys(output.tags), "Attributes")
    error_message = "attributes belong in the id, not as an undocumented Attributes tag (labels_as_tags is pinned)"
  }
}

run "namespace_required" {
  command = plan

  variables {
    region = "uk"
    stage  = "prd"
    name   = "api"
    # no namespace, via variable or context
  }

  expect_failures = [output.id]
}

run "namespace_normalizing_to_empty_rejected" {
  command = plan

  # "_" is non-empty as a raw input but CloudPosse normalizes it to empty; the
  # precondition checks the normalized output, so this is rejected.
  variables {
    namespace = "_"
    region    = "uk"
    stage     = "prd"
    name      = "api"
  }

  expect_failures = [output.id]
}

run "eu_stg_region" {
  command = plan

  variables {
    namespace   = "cnct"
    region      = "eu"
    stage       = "stg"
    application = "mobile"
    name        = "api"
  }

  assert {
    condition     = output.id == "cnct-eu-stg-mobile-api"
    error_message = "id for cnct/eu/stg mismatch, got ${output.id}"
  }
}

run "invalid_aws_region_rejected" {
  command = plan

  variables {
    namespace  = "cnct"
    aws_region = "notaregion"
    name       = "api"
  }

  expect_failures = [var.aws_region]
}

run "non_prd_naming" {
  command = plan

  variables {
    namespace = "cnct"
    region    = "uk"
    stage     = "stg"
    non_prd   = true
    name      = "shared"
  }

  assert {
    condition     = output.id == "cnct-uk-np-shared"
    error_message = "non_prd id mismatch, got ${output.id}"
  }
  assert {
    condition     = output.tags["Stage"] == "np"
    error_message = "non_prd Stage tag should be np"
  }
}

run "non_prd_with_prd_stage_rejected" {
  command = plan

  # A caller who sets stage = "prd" while inheriting non_prd = true (e.g. from a
  # parent context) would get a production resource silently tagged Stage = "np".
  # The contradiction is rejected, not resolved.
  variables {
    namespace = "cnct"
    region    = "uk"
    stage     = "prd"
    non_prd   = true
    name      = "shared"
  }

  expect_failures = [output.id]
}

run "mixed_case_input_normalized_consistently" {
  command = plan

  # CloudPosse lowercases every id segment and strips all but [-a-zA-Z0-9]; AWS
  # tag filters are case-sensitive, so the ohi:* values must use the id's
  # normalized spelling — including the segments CloudPosse never sees
  # (application, module), which are normalized with the same rule.
  variables {
    namespace   = "CNCT"
    region      = "UK"
    stage       = "prd"
    application = "My.App"
    module      = "BE"
    name        = "api"
  }

  assert {
    condition     = output.id == "cnct-uk-prd-myapp-api"
    error_message = "mixed-case input should normalize in the id, got ${output.id}"
  }
  assert {
    condition     = output.tags["ohi:stack-name"] == "cnct-uk-prd-myapp-be"
    error_message = "ohi:stack-name must use the id's normalized spelling, got ${output.tags["ohi:stack-name"]}"
  }
  assert {
    condition     = output.tags["ohi:application"] == "myapp"
    error_message = "ohi:application must use the id's normalized spelling, got ${output.tags["ohi:application"]}"
  }
  assert {
    condition     = output.tags["ohi:module"] == "myapp-be"
    error_message = "ohi:module must use the id's normalized spelling, got ${output.tags["ohi:module"]}"
  }
}

run "bare_tag_prefix" {
  command = plan

  variables {
    namespace   = "cnct"
    region      = "uk"
    stage       = "prd"
    application = "mobile"
    name        = "api"
    tag_prefix  = ""
  }

  assert {
    condition     = output.tags["application"] == "mobile"
    error_message = "empty tag_prefix should yield an unprefixed 'application' key"
  }
  assert {
    condition     = !contains(keys(output.tags), "ohi:application")
    error_message = "empty tag_prefix should not produce an ohi:application key"
  }
  assert {
    condition     = output.tags["Name"] == "cnct-uk-prd-mobile-api"
    error_message = "CloudPosse's Name tag is unaffected by tag_prefix and should equal the id"
  }
}

run "infra_set_composition" {
  command = plan

  # The infra/default set: no application, just a module under the namespace.
  variables {
    namespace = "cnct"
    region    = "uk"
    stage     = "prd"
    module    = "infra"
  }

  assert {
    condition     = !contains(keys(output.tags), "ohi:application")
    error_message = "with no application, ohi:application should be omitted"
  }
  assert {
    condition     = output.tags["ohi:module"] == "infra"
    error_message = "module with no application composes to just <module>, got ${output.tags["ohi:module"]}"
  }
  assert {
    condition     = output.tags["ohi:stack-name"] == "cnct-uk-prd-infra"
    error_message = "ohi:stack-name should derive to <namespace>-<region>-<stage>-<ohi:module>, got ${output.tags["ohi:stack-name"]}"
  }
}

run "module_composes_under_application" {
  command = plan

  variables {
    namespace   = "cnct"
    application = "mobile"
    module      = "report"
  }

  assert {
    condition     = output.tags["ohi:application"] == "mobile"
    error_message = "ohi:application should be the application segment"
  }
  assert {
    condition     = output.tags["ohi:module"] == "mobile-report"
    error_message = "module composes under application, got ${output.tags["ohi:module"]}"
  }
}

run "stack_suffix_override" {
  command = plan

  # The optional escape hatch pins ohi:stack-name to
  # <namespace>-<region>-<stage>-<stack_suffix>, overriding the derived hierarchy.
  variables {
    namespace    = "cnct"
    region       = "uk"
    stage        = "prd"
    application  = "mobile"
    module       = "be"
    stack_suffix = "legacy-be-stack"
  }

  assert {
    condition     = output.tags["ohi:stack-name"] == "cnct-uk-prd-legacy-be-stack"
    error_message = "stack_suffix should override ohi:stack-name, got ${output.tags["ohi:stack-name"]}"
  }
}
