# id_length_limit truncation and AWS tag constraints (key/value length, key
# non-empty, user-tag count).

run "id_truncated_to_limit" {
  command = plan

  # id_full = usstg-usw2-vlt-mobile-api-with-a-very-long-name-segment (> 20).
  # With id_length_limit = 20 and a 5-char hash + 1-char delimiter, the leading
  # 14 chars are kept ("usstg-usw2-vlt"), then "-" + a 5-char hash -> 20 chars.
  variables {
    country           = "us"
    environment       = "stg"
    deployment_region = "usw2"
    name              = "vlt-mobile-api-with-a-very-long-name-segment"
    id_length_limit   = 20
  }

  assert {
    condition     = length(output.id) == 20
    error_message = "id should be truncated to exactly 20 chars, got ${length(output.id)} (${output.id})"
  }
  assert {
    condition     = substr(output.id, 0, 15) == "usstg-usw2-vlt-"
    error_message = "truncated id should keep the leading segment + delimiter, got ${output.id}"
  }
  assert {
    condition     = output.id != output.id_full
    error_message = "id should differ from id_full when truncated"
  }
  assert {
    condition     = output.id_full == "usstg-usw2-vlt-mobile-api-with-a-very-long-name-segment"
    error_message = "id_full should be the untruncated id, got ${output.id_full}"
  }
  assert {
    condition     = output.tags["Name"] == output.id
    error_message = "Name tag should equal the truncated id"
  }
  assert {
    condition     = output.context.id_length_limit == 20
    error_message = "id_length_limit should be carried in context for inheritance"
  }
}

run "id_not_truncated_when_within_limit" {
  command = plan

  variables {
    country           = "us"
    environment       = "stg"
    deployment_region = "usw2"
    name              = "api"
    id_length_limit   = 100
  }

  assert {
    condition     = output.id == "usstg-usw2-api" && output.id == output.id_full
    error_message = "an id within the limit should be untouched, got ${output.id}"
  }
}

run "id_unlimited_by_default" {
  command = plan

  # id_length_limit defaults to 0 (unlimited): no truncation regardless of length.
  variables {
    country           = "us"
    environment       = "stg"
    deployment_region = "usw2"
    name              = "vlt-mobile-api-with-a-very-long-name-segment"
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
    project = "vlt"
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
    project = "vlt"
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
    project = "vlt"
    tags = {
      (join("", [for i in range(129) : "k"])) = "v"
    }
  }

  expect_failures = [output.tags]
}

run "empty_tag_key_rejected" {
  command = plan

  variables {
    project = "vlt"
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
    project = "vlt"
    tags    = { for i in range(51) : "key-${i}" => "v" }
  }

  expect_failures = [output.tags]
}

run "fifty_user_tags_allowed" {
  command = plan

  variables {
    project = "vlt"
    tags    = { for i in range(50) : "key-${i}" => "v" }
  }

  assert {
    condition     = output.tags["key-0"] == "v"
    error_message = "exactly 50 user tags should be allowed"
  }
}
