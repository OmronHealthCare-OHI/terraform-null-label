# tag_prefix / tag_delimiter: context inheritance (null default) and the AWS
# tag-key character / reserved-prefix validations.

run "inherits_tag_prefix_and_delimiter_from_context" {
  command = plan

  # tag_prefix/tag_delimiter are unset here; with a null default they must be
  # inherited from context rather than falling back to the module defaults.
  variables {
    project = "vlt"
    context = {
      tag_prefix    = "custom"
      tag_delimiter = "."
    }
  }

  assert {
    condition     = output.tags["custom.project"] == "vlt"
    error_message = "tag_prefix/tag_delimiter should be inherited from context (expected key custom.project)"
  }
}

run "explicit_tag_prefix_delimiter_override_context" {
  command = plan

  variables {
    project       = "vlt"
    tag_prefix    = "ohi"
    tag_delimiter = ":"
    context = {
      tag_prefix    = "custom"
      tag_delimiter = "."
    }
  }

  assert {
    condition     = output.tags["ohi:project"] == "vlt"
    error_message = "explicit tag_prefix/tag_delimiter should override the inherited context"
  }
}

run "reserved_aws_tag_prefix_rejected" {
  command = plan

  variables {
    tag_prefix = "AWS"
  }

  expect_failures = [var.tag_prefix]
}

run "invalid_char_tag_prefix_rejected" {
  command = plan

  variables {
    tag_prefix = "oh!"
  }

  expect_failures = [var.tag_prefix]
}

run "invalid_char_tag_delimiter_rejected" {
  command = plan

  variables {
    tag_delimiter = "*"
  }

  expect_failures = [var.tag_delimiter]
}
