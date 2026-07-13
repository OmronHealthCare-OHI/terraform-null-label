output "id" {
  description = "The generated resource id: <PREFIX>-<name>[-<attributes>] (empty when enabled = false)."
  value       = local.id
}

output "name" {
  description = "The resolved name segment (the `name` input, inherited via context). Use `id` for the full generated identifier."
  value       = local.name
}

output "prefix" {
  description = "The computed PREFIX: <country><environment>-<deployment_region> (or <country>np-<region> when non_prd)."
  value       = local.prefix
}

output "tags" {
  description = "The generated tags: the required ohi:* tags + Name, merged with any additional tags."
  value       = local.tags
}

output "enabled" {
  description = "Whether this label is enabled."
  value       = local.enabled
}

output "context" {
  description = "The label context to pass to child label modules."
  value       = local.output_context
}
