locals {
  defaults = {
    delimiter      = "-"
    enabled        = true
    non_prd        = false
    prefix_enabled = true
  }

  # Explicit variables override the inherited context (null = inherit).
  # attributes and tags are merged (context first, then explicit value).
  input = {
    enabled           = var.enabled == null ? var.context.enabled : var.enabled
    country           = var.country == null ? var.context.country : var.country
    environment       = var.environment == null ? var.context.environment : var.environment
    deployment_region = var.deployment_region == null ? var.context.deployment_region : var.deployment_region
    project           = var.project == null ? var.context.project : var.project
    application       = var.application == null ? var.context.application : var.application
    module            = var.module == null ? var.context.module : var.module
    stackname         = var.stackname == null ? var.context.stackname : var.stackname
    name              = var.name == null ? var.context.name : var.name
    non_prd           = var.non_prd == null ? var.context.non_prd : var.non_prd
    delimiter         = var.delimiter == null ? var.context.delimiter : var.delimiter
    prefix_enabled    = var.prefix_enabled == null ? var.context.prefix_enabled : var.prefix_enabled
    attributes        = compact(distinct(concat(coalesce(var.context.attributes, []), coalesce(var.attributes, []))))
    tags              = merge(var.context.tags, var.tags)
  }

  enabled   = local.input.enabled
  delimiter = local.input.delimiter == null ? local.defaults.delimiter : local.input.delimiter

  country     = local.input.country == null ? "" : local.input.country
  environment = local.input.environment == null ? "" : local.input.environment
  region      = local.input.deployment_region == null ? "" : local.input.deployment_region
  name        = local.input.name == null ? "" : local.input.name

  # PREFIX environment segment: <country><environment>, or <country>np when non_prd.
  environment_segment = local.input.non_prd ? (local.country == "" ? "" : "${local.country}np") : "${local.country}${local.environment}"

  # PREFIX = <environment_segment>-<deployment_region>, e.g. usstg-usw2 / usnp-usw2.
  prefix = join(local.delimiter, compact([local.environment_segment, local.region]))

  # id = <PREFIX>-<name>[-<attributes...>], prefix optional.
  id_parts = local.input.prefix_enabled ? concat([local.prefix, local.name], local.input.attributes) : concat([local.name], local.input.attributes)
  id       = local.enabled ? join(local.delimiter, compact(local.id_parts)) : ""

  # Required OMRON tags (only emitted when non-empty), plus AWS Name = id.
  ohi_tags_all = {
    "ohi:project"     = local.input.project
    "ohi:application" = local.input.application
    "ohi:module"      = local.input.module
    "ohi:stack-name"  = local.input.stackname
    "ohi:environment" = local.prefix
    "Name"            = local.id
  }
  ohi_tags = { for k, v in local.ohi_tags_all : k => v if v != null && v != "" }

  tags = local.enabled ? merge(local.ohi_tags, local.input.tags) : {}

  # Context to pass to child label modules. Carries the semantic fields and the
  # user-supplied tags only; each level re-derives ohi:*/Name from the fields.
  output_context = {
    enabled           = local.enabled
    country           = local.input.country
    environment       = local.input.environment
    deployment_region = local.input.deployment_region
    project           = local.input.project
    application       = local.input.application
    module            = local.input.module
    stackname         = local.input.stackname
    name              = local.input.name
    attributes        = local.input.attributes
    non_prd           = local.input.non_prd
    delimiter         = local.delimiter
    prefix_enabled    = local.input.prefix_enabled
    tags              = local.input.tags
  }
}
