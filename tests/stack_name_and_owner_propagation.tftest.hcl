# stack_name_enabled / owner_propagation_enabled: the ohi:stack-name tag can be
# dropped, and owner can be withheld from the exported context so child labels
# do not silently adopt it. Chain behaviour lives in ./tests/propagation_chain.

run "stack_name_tag_emitted_by_default" {
  command = plan

  variables {
    country           = "us"
    stage             = "stg"
    deployment_region = "usw2"
    project           = "vlt"
    application       = "mobile"
    module            = "be"
  }

  assert {
    condition     = output.tags["ohi:stack-name"] == "usstg-usw2-vlt-mobile-be"
    error_message = "ohi:stack-name should be emitted by default, got ${jsonencode(output.tags)}"
  }
}

run "stack_name_tag_dropped_when_disabled" {
  command = plan

  variables {
    country            = "us"
    stage              = "stg"
    deployment_region  = "usw2"
    project            = "vlt"
    application        = "mobile"
    module             = "be"
    stack_name_enabled = false
  }

  assert {
    condition     = !contains(keys(output.tags), "ohi:stack-name")
    error_message = "ohi:stack-name should be dropped when stack_name_enabled = false"
  }

  # The other generated tags are unaffected.
  assert {
    condition     = output.tags["ohi:module"] == "vlt-mobile-be"
    error_message = "disabling the stack-name tag should not affect the other ohi:* tags"
  }

  # The disable is carried into the exported context for child labels.
  assert {
    condition     = output.context.stack_name_enabled == false
    error_message = "stack_name_enabled = false should be exported via context"
  }
}

run "owner_propagates_by_default" {
  command = plan

  variables {
    project = "vlt"
    owner   = "vlt-mobile-circle"
  }

  assert {
    condition     = output.tags["ohi:owner"] == "vlt-mobile-circle"
    error_message = "owner should be emitted as the ohi:owner tag"
  }
  assert {
    condition     = output.context.owner == "vlt-mobile-circle"
    error_message = "owner should be carried into the exported context by default"
  }
}

run "owner_withheld_from_context_when_propagation_disabled" {
  command = plan

  variables {
    project                   = "vlt"
    owner                     = "vlt-mobile-circle"
    owner_propagation_enabled = false
  }

  # This label still tags itself with its own owner...
  assert {
    condition     = output.tags["ohi:owner"] == "vlt-mobile-circle"
    error_message = "disabling propagation should not drop this label's own ohi:owner tag"
  }

  # ...but the exported context carries no owner.
  assert {
    condition     = output.context.owner == null
    error_message = "owner should be withheld from the exported context when owner_propagation_enabled = false"
  }

  # owner_propagation_enabled is a ONE-LEVEL ownership reset — it must never
  # travel via context, or one reset high in the tree silently disables owner
  # propagation for the whole subtree. The context drops `owner`; the toggle
  # itself stays local.
  assert {
    condition     = !contains(keys(output.context), "owner_propagation_enabled")
    error_message = "owner_propagation_enabled must not be part of the exported context — it is a one-level ownership reset"
  }
}

run "chain_owner_not_adopted_and_stack_name_stays_disabled" {
  command = plan

  module {
    source = "./tests/propagation_chain"
  }

  # The child inherits no owner: no ohi:owner tag on the child.
  assert {
    condition     = !contains(keys(output.child_tags), "ohi:owner")
    error_message = "child should not adopt the parent's owner when propagation is disabled"
  }

  # The stack-name disable is inherited through the chain.
  assert {
    condition     = !contains(keys(output.child_tags), "ohi:stack-name")
    error_message = "child should inherit stack_name_enabled = false from context"
  }

  # A child that states its own owner tags itself with it (explicit var beats
  # the withheld context)...
  assert {
    condition     = output.owned_child_tags["ohi:owner"] == "other-circle"
    error_message = "a child stating its own owner should emit its own ohi:owner tag"
  }

  # ...and a child can locally re-enable the stack-name tag.
  assert {
    condition     = output.owned_child_tags["ohi:stack-name"] == "usstg-usw2-vlt-mobile-be"
    error_message = "a child setting stack_name_enabled = true should emit ohi:stack-name again"
  }

  # The reset is ONE level deep: the parent's toggle does not travel, so a
  # child that states its own owner exports it to grandchildren normally.
  assert {
    condition     = output.owned_child_context.owner == "other-circle"
    error_message = "the parent's owner_propagation_enabled = false must not carry down — a child stating its own owner should export it via context"
  }
}
