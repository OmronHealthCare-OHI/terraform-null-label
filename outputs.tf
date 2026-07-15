output "id" {
  description = "The generated id: the non-empty segments joined by the delimiter — <PREFIX>, <name>, then <attributes...>. The prefix is omitted when prefix_enabled = false, and attributes may appear without a name (CloudPosse null-label parity). Truncated (with a trailing hash) when it exceeds id_length_limit. Empty when enabled = false."
  value       = local.id
}

output "id_full" {
  description = "The untruncated id, before any id_length_limit is applied. Equals id when id_length_limit is 0 (unlimited) or the id already fits."
  value       = local.id_full
}

output "name" {
  description = "The resolved name segment (the `name` input, inherited via context). Use `id` for the full generated identifier."
  value       = local.name
}

output "prefix" {
  description = "The computed PREFIX: <country><stage>-<deployment_region> (or <country>np-<region> when non_prd)."
  value       = local.prefix
}

output "tags" {
  description = "The generated tags: the required ohi:* tags + Name, merged with any additional tags. Values are capped at 256 Unicode characters."
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
    condition     = !local.enabled || local.user_tag_count <= local.max_user_tags
    error_message = "A resource may have at most ${local.max_user_tags} user-created tags; got ${local.user_tag_count}."
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
