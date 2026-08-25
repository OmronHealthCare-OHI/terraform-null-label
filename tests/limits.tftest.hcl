# id_length_limit truncation (delegated to CloudPosse null-label) and the OMRON
# AWS tag constraints (key/value length, key non-empty, user-tag count) applied
# to the merged CloudPosse + ohi:* + user tag set.
#
# BEHAVIOUR CHANGE (2026-08-25, CloudPosse wrap): the `Name` tag now equals the
# *truncated* id (CloudPosse emits Name = id), where the old bespoke module made
# Name carry the full id bound only by the tag-value limit. The old
# `name_tag_capped_at_value_limit_not_id_limit` run block is dropped. Confirm
# whether Name-carries-full-id should be reinstated by overriding the Name tag.

run "id_truncated_to_limit" {
  command = plan

  variables {
    namespace       = "cnct"
    region          = "uk"
    stage           = "prd"
    name            = "mobile-api-with-a-very-long-name-segment"
    id_length_limit = 20
  }

  assert {
    condition     = length(output.id) == 20
    error_message = "id should be truncated to at most 20 chars, got ${length(output.id)} (${output.id})"
  }
  assert {
    condition     = output.id != output.id_full
    error_message = "id should differ from id_full when truncated"
  }
  assert {
    condition     = output.id_full == "cnct-uk-prd-mobile-api-with-a-very-long-name-segment"
    error_message = "id_full should be the untruncated id, got ${output.id_full}"
  }
  assert {
    condition     = output.tags["Name"] == output.id
    error_message = "CloudPosse Name tag equals the (truncated) id, got ${output.tags["Name"]}"
  }
  assert {
    condition     = output.context.id_length_limit == 20
    error_message = "id_length_limit should be carried in context for inheritance"
  }
}

run "id_not_truncated_when_within_limit" {
  command = plan

  variables {
    namespace       = "cnct"
    region          = "uk"
    stage           = "prd"
    name            = "api"
    id_length_limit = 100
  }

  assert {
    condition     = output.id == "cnct-uk-prd-api" && output.id == output.id_full
    error_message = "an id within the limit should be untouched, got ${output.id}"
  }
}

run "id_unlimited_by_default" {
  command = plan

  variables {
    namespace = "cnct"
    region    = "uk"
    stage     = "prd"
    name      = "mobile-api-with-a-very-long-name-segment"
  }

  assert {
    condition     = output.id == output.id_full
    error_message = "with the default (unlimited) limit the id should never be truncated"
  }
}

run "id_length_limit_below_minimum_rejected" {
  command = plan

  variables {
    id_length_limit = 3
  }

  expect_failures = [var.id_length_limit]
}

run "tag_value_truncated_to_256" {
  command = plan

  # A 300-char value is capped to 256: first 251 original chars + 5-char hash.
  variables {
    namespace = "cnct"
    tags = {
      long = join("", [for i in range(300) : "a"])
    }
  }

  assert {
    condition     = length(output.tags["long"]) == 256
    error_message = "an over-long tag value should be capped at 256 chars, got ${length(output.tags["long"])}"
  }
  assert {
    condition     = substr(output.tags["long"], 0, 251) == join("", [for i in range(251) : "a"])
    error_message = "the capped value should keep the leading 251 original characters"
  }
}

run "tag_value_within_limit_untouched" {
  command = plan

  variables {
    namespace = "cnct"
    tags = {
      short = "a-normal-value"
    }
  }

  assert {
    condition     = output.tags["short"] == "a-normal-value"
    error_message = "a value within 256 chars should be untouched"
  }
}

run "oversized_tag_key_rejected" {
  command = plan

  # A 129-char key exceeds the 128-char AWS limit.
  variables {
    namespace = "cnct"
    tags = {
      (join("", [for i in range(129) : "k"])) = "v"
    }
  }

  expect_failures = [output.tags]
}

run "empty_tag_key_rejected" {
  command = plan

  variables {
    namespace = "cnct"
    tags = {
      "" = "v"
    }
  }

  expect_failures = [output.tags]
}

run "too_many_user_tags_rejected" {
  command = plan

  # 51 user tags exceeds the 50-tag limit.
  variables {
    namespace = "cnct"
    tags      = { for i in range(51) : "key-${i}" => "v" }
  }

  expect_failures = [output.tags]
}

run "fifty_user_tags_allowed" {
  command = plan

  variables {
    namespace = "cnct"
    tags      = { for i in range(50) : "key-${i}" => "v" }
  }

  assert {
    condition     = output.tags["key-0"] == "v"
    error_message = "exactly 50 user tags should be allowed"
  }
}

run "invalid_tag_key_char_rejected" {
  command = plan

  variables {
    namespace = "cnct"
    tags = {
      "bad!key" = "v"
    }
  }

  expect_failures = [output.tags]
}

run "invalid_tag_value_char_rejected" {
  command = plan

  variables {
    namespace = "cnct"
    tags = {
      good = "bad*value"
    }
  }

  expect_failures = [output.tags]
}

run "reserved_aws_prefix_user_key_rejected" {
  command = plan

  # A user-supplied key beginning with the reserved aws: prefix.
  variables {
    namespace = "cnct"
    tags = {
      "aws:foo" = "v"
    }
  }

  expect_failures = [output.tags]
}

run "reserved_aws_tag_prefix_rejected" {
  command = plan

  # A tag_prefix that slips past the variable check but still composes aws:*
  # keys (here "aws:" + ":" delimiter -> aws::application) is caught by the
  # output precondition that guards the final key set.
  variables {
    namespace   = "cnct"
    application = "mobile"
    tag_prefix  = "aws:"
  }

  expect_failures = [output.tags]
}

run "allowed_special_chars_ok" {
  command = plan

  # Every AWS-permitted special character in a key and value should pass.
  variables {
    namespace = "cnct"
    tags = {
      "a_b.c:d/e=f+g-h@i" = "v_1.2:3/4=5+6-7@8 z"
    }
  }

  assert {
    condition     = output.tags["a_b.c:d/e=f+g-h@i"] == "v_1.2:3/4=5+6-7@8 z"
    error_message = "keys/values using the allowed special characters should pass unchanged"
  }
}

run "custom_max_tag_value_length_truncates" {
  command = plan

  # A tighter per-service value ceiling still truncates with a hash: 30 chars
  # capped to 20 (15 leading + 5-char hash).
  variables {
    namespace            = "cnct"
    max_tag_value_length = 20
    tags = {
      long = join("", [for i in range(30) : "a"])
    }
  }

  assert {
    condition     = length(output.tags["long"]) == 20
    error_message = "a custom max_tag_value_length should cap the value, got ${length(output.tags["long"])}"
  }
}

run "custom_max_tag_key_length_rejected" {
  command = plan

  # Tighter key ceiling (10) with an 11-char user key. No region/stage so the
  # only generated keys are Namespace (9) and Name (4), within the ceiling.
  variables {
    namespace          = "cnct"
    tag_prefix         = ""
    max_tag_key_length = 10
    tags = {
      "12345678901" = "v"
    }
  }

  expect_failures = [output.tags]
}

run "max_tag_value_length_out_of_range_rejected" {
  command = plan

  variables {
    max_tag_value_length = 500
  }

  expect_failures = [var.max_tag_value_length]
}

run "empty_valued_user_tags_not_counted" {
  command = plan

  # 51 user tags, but 2 have empty values (dropped) -> 49 emitted, under the cap.
  variables {
    namespace = "cnct"
    tags = merge(
      { for i in range(49) : "key-${i}" => "v" },
      { "empty-a" = "", "empty-b" = "" },
    )
  }

  assert {
    condition     = !contains(keys(output.tags), "empty-a")
    error_message = "empty-valued tags should be dropped"
  }
  assert {
    condition     = output.tags["key-0"] == "v"
    error_message = "51 declared tags with 2 empty values (49 emitted) should be allowed"
  }
}

run "multichar_delimiter_small_limit" {
  command = plan

  # A 2-char delimiter with the minimum limit. Truncation is CloudPosse's; the
  # id stays non-empty and within the limit.
  variables {
    namespace       = "cnct"
    region          = "uk"
    stage           = "prd"
    name            = "mobile-api-with-a-very-long-name-segment"
    delimiter       = "__"
    id_length_limit = 6
  }

  assert {
    condition     = output.id != "" && length(output.id) <= 6
    error_message = "with limit 6 the id should be non-empty and within the limit, got ${length(output.id)} (${output.id})"
  }
}
