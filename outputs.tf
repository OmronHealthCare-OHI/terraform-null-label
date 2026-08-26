output "id" {
  description = "The generated id from CloudPosse null-label: <namespace>-<region>-<stage>-<name>-<attributes...> (module is not part of the id — it lives in the ohi:module tag). Truncated (with a trailing hash) when it exceeds id_length_limit. Empty when enabled = false."
  value       = module.cloudposse_label.id

  precondition {
    condition     = local.namespace_present
    error_message = "namespace is required when the label is enabled: set the `namespace` variable or provide it through `context` (e.g. cnct, crt, luscii)."
  }
  # non_prd collapses the non-prod stages into "np"; combined with stage = "prd"
  # it would silently tag a production resource Stage = "np" — worst when
  # non_prd is inherited via context. Contradictions are rejected, not resolved.
  precondition {
    condition     = !(local.non_prd && local.stage == "prd")
    error_message = "non_prd = true cannot be combined with stage = \"prd\": the resource would be tagged Stage = \"np\"."
  }
}

output "id_full" {
  description = "The untruncated id, before any id_length_limit is applied. Equals id when id_length_limit is 0 (unlimited) or the id already fits."
  value       = module.cloudposse_label.id_full
}

output "name" {
  description = "The normalized name component (the composed <application>-<name> leaf). Use `id` for the full generated identifier."
  value       = module.cloudposse_label.name
}

output "namespace" {
  description = "The resolved namespace (product token)."
  value       = module.cloudposse_label.namespace
}

output "region" {
  description = "The resolved logical region (CloudPosse environment segment)."
  value       = module.cloudposse_label.environment
}

output "stage" {
  description = "The resolved stage segment (\"np\" when non_prd)."
  value       = module.cloudposse_label.stage
}

output "tags" {
  description = "The generated tags: CloudPosse's Namespace/Environment/Stage/Name + the OMRON ohi:* tags (ohi:application, ohi:module, ohi:stack-name, ohi:owner, ohi:aws-region), merged with any additional tags. Values are capped at max_tag_value_length Unicode characters (default 256, the AWS ceiling)."
  value       = local.tags

  precondition {
    condition     = length(local.oversized_tag_keys) == 0
    error_message = "Tag keys must be at most ${local.max_tag_key_length} Unicode characters. Offending keys: ${join(", ", local.oversized_tag_keys)}."
  }
  precondition {
    condition     = !local.has_empty_tag_key
    error_message = "Tag keys must not be empty strings."
  }
  precondition {
    condition     = length(local.invalid_char_keys) == 0
    error_message = "Tag keys may only contain letters, numbers, spaces and _ . : / = + - @. Offending keys: ${join(", ", local.invalid_char_keys)}."
  }
  precondition {
    condition     = length(local.reserved_prefix_keys) == 0
    error_message = "Tag keys must not begin with the reserved \"aws:\" prefix. Offending keys: ${join(", ", local.reserved_prefix_keys)}."
  }
  precondition {
    condition     = length(local.invalid_value_keys) == 0
    error_message = "Tag values may only contain letters, numbers, spaces and _ . : / = + - @. Offending keys: ${join(", ", local.invalid_value_keys)}."
  }
  precondition {
    condition     = !local.enabled || local.emitted_tag_count <= local.max_user_tags
    error_message = "A resource may have at most ${local.max_user_tags} tags (generated ohi:*/CloudPosse tags count too); the label would emit ${local.emitted_tag_count}."
  }
}

output "enabled" {
  description = "Whether this label is enabled."
  value       = local.enabled
}

output "context" {
  description = "The label context to pass to child label modules."
  value       = local.output_context
}
