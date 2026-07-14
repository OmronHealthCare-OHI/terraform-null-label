# Resource naming — a fully specified label produces the OMRON-standard id and tags.

run "full_label_us_stg" {
  command = plan

  variables {
    country           = "us"
    stage       = "stg"
    deployment_region = "usw2"
    project           = "vlt"
    application       = "mobile"
    module            = "be"
    stack_suffix      = "be-serverless-stack"
    name              = "vlt-mobile-api"
    attributes        = ["v1"]
  }

  assert {
    condition     = output.prefix == "usstg-usw2"
    error_message = "PREFIX should be <country><stage>-<region> (usstg-usw2), got ${output.prefix}"
  }
  assert {
    condition     = output.id == "usstg-usw2-vlt-mobile-api-v1"
    error_message = "id should be <PREFIX>-<name>-<attributes>, got ${output.id}"
  }
  assert {
    condition     = output.tags["ohi:project"] == "vlt"
    error_message = "ohi:project tag mismatch"
  }
  assert {
    condition     = output.tags["ohi:application"] == "vlt-mobile"
    error_message = "ohi:application tag mismatch"
  }
  assert {
    condition     = output.tags["ohi:module"] == "vlt-mobile-be"
    error_message = "ohi:module tag mismatch"
  }
  assert {
    condition     = output.tags["ohi:stack-name"] == "usstg-usw2-vlt-be-serverless-stack"
    error_message = "ohi:stack-name tag mismatch"
  }
  assert {
    condition     = output.tags["ohi:environment"] == "usstg-usw2"
    error_message = "ohi:environment tag should equal the prefix"
  }
  assert {
    condition     = output.tags["Name"] == "usstg-usw2-vlt-mobile-api-v1"
    error_message = "Name tag should equal the id"
  }
}

run "eu_stg_region" {
  command = plan

  variables {
    country           = "eu"
    stage       = "stg"
    deployment_region = "euw1"
    name              = "vlt-mobile-api"
  }

  assert {
    condition     = output.id == "eustg-euw1-vlt-mobile-api"
    error_message = "id for eu/stg/euw1 mismatch, got ${output.id}"
  }
}

run "deployment_region_derived_from_aws_region" {
  command = plan

  # deployment_region is unset, so it is derived from aws_region:
  # us-west-2 -> usw2 (<part0><first-letter-of-part1><part2>).
  variables {
    country     = "us"
    stage       = "stg"
    aws_region  = "us-west-2"
    name        = "vlt-mobile-api"
  }

  assert {
    condition     = output.prefix == "usstg-usw2"
    error_message = "aws_region us-west-2 should derive deployment_region usw2, got prefix ${output.prefix}"
  }
}

run "deployment_region_derived_multiletter" {
  command = plan

  # eu-central-1 -> euc1, ap-northeast-1 -> apn1.
  variables {
    country     = "eu"
    stage       = "stg"
    aws_region  = "eu-central-1"
    name        = "vlt-mobile-api"
  }

  assert {
    condition     = output.prefix == "eustg-euc1"
    error_message = "aws_region eu-central-1 should derive deployment_region euc1, got prefix ${output.prefix}"
  }
}

run "explicit_deployment_region_overrides_aws_region" {
  command = plan

  # An explicit deployment_region wins over the value derived from aws_region.
  variables {
    country           = "us"
    stage             = "stg"
    aws_region        = "us-west-2"
    deployment_region = "use1"
    name              = "vlt-mobile-api"
  }

  assert {
    condition     = output.prefix == "usstg-use1"
    error_message = "explicit deployment_region should override the aws_region derivation, got ${output.prefix}"
  }
}

run "invalid_aws_region_rejected" {
  command = plan

  variables {
    aws_region = "notaregion"
    name       = "vlt-mobile-api"
  }

  expect_failures = [var.aws_region]
}

run "non_prd_naming" {
  command = plan

  variables {
    country           = "us"
    stage       = "stg"
    deployment_region = "usw2"
    non_prd           = true
    name              = "vlt-shared"
  }

  assert {
    condition     = output.prefix == "usnp-usw2"
    error_message = "non_prd prefix should be <country>np-<region> (usnp-usw2), got ${output.prefix}"
  }
  assert {
    condition     = output.id == "usnp-usw2-vlt-shared"
    error_message = "non_prd id mismatch, got ${output.id}"
  }
  assert {
    condition     = output.tags["ohi:environment"] == "usnp-usw2"
    error_message = "non_prd ohi:environment mismatch"
  }
}

run "prefix_suppressed" {
  command = plan

  variables {
    country           = "us"
    stage       = "stg"
    deployment_region = "usw2"
    prefix_enabled    = false
    name              = "vlt-service-secrets"
  }

  assert {
    condition     = output.id == "vlt-service-secrets"
    error_message = "prefix_enabled=false should drop the prefix (stage-invariant name), got ${output.id}"
  }
}

run "bare_tag_prefix" {
  command = plan

  variables {
    country           = "us"
    stage       = "stg"
    deployment_region = "usw2"
    project           = "vlt"
    name              = "vlt-mobile-api"
    tag_prefix        = ""
  }

  assert {
    condition     = output.tags["project"] == "vlt"
    error_message = "empty tag_prefix should yield an unprefixed 'project' key"
  }
  assert {
    condition     = !contains(keys(output.tags), "ohi:project")
    error_message = "empty tag_prefix should not produce an ohi:project key"
  }
  assert {
    condition     = output.tags["Name"] == "usstg-usw2-vlt-mobile-api"
    error_message = "Name tag is never prefixed and should equal the id"
  }
}

run "infra_set_composition" {
  command = plan

  # The infra/default set: application equals the project, so the application
  # segment is empty; module composes to <project>-infra.
  variables {
    country           = "us"
    stage       = "stg"
    deployment_region = "usw2"
    project           = "vlt"
    application       = ""
    module            = "infra"
    stack_suffix      = "tf-initial-setup-pipeline"
  }

  assert {
    condition     = output.tags["ohi:application"] == "vlt"
    error_message = "empty application segment should make ohi:application == project"
  }
  assert {
    condition     = output.tags["ohi:module"] == "vlt-infra"
    error_message = "module should compose to <project>-infra, got ${output.tags["ohi:module"]}"
  }
  assert {
    condition     = output.tags["ohi:stack-name"] == "usstg-usw2-vlt-tf-initial-setup-pipeline"
    error_message = "ohi:stack-name should be <PREFIX>-<project>-<stack_suffix>"
  }
}

run "report_normalizes_under_composition" {
  command = plan

  # Strict composition normalizes the legacy "report" exception (was vlt-report
  # under application vlt-mobile) to vlt-mobile-report.
  variables {
    project     = "vlt"
    application = "mobile"
    module      = "report"
  }

  assert {
    condition     = output.tags["ohi:application"] == "vlt-mobile"
    error_message = "ohi:application should compose to vlt-mobile"
  }
  assert {
    condition     = output.tags["ohi:module"] == "vlt-mobile-report"
    error_message = "module composes under application (normalizes the legacy vlt-report), got ${output.tags["ohi:module"]}"
  }
}
