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
    stage             = var.stage == null ? var.context.stage : var.stage
    aws_region        = var.aws_region == null ? var.context.aws_region : var.aws_region
    deployment_region = var.deployment_region == null ? var.context.deployment_region : var.deployment_region
    project           = var.project == null ? var.context.project : var.project
    application       = var.application == null ? var.context.application : var.application
    module            = var.module == null ? var.context.module : var.module
    stack_suffix      = var.stack_suffix == null ? var.context.stack_suffix : var.stack_suffix
    name              = var.name == null ? var.context.name : var.name
    non_prd           = var.non_prd == null ? var.context.non_prd : var.non_prd
    delimiter         = var.delimiter == null ? var.context.delimiter : var.delimiter
    prefix_enabled    = var.prefix_enabled == null ? var.context.prefix_enabled : var.prefix_enabled
    tag_prefix        = var.tag_prefix == null ? var.context.tag_prefix : var.tag_prefix
    attributes        = compact(distinct(concat(coalesce(var.context.attributes, []), coalesce(var.attributes, []))))
    tags              = merge(coalesce(var.context.tags, {}), coalesce(var.tags, {}))
  }

  # Coalesce to defaults so an explicit null (as a variable or via context) can't
  # break the conditionals below (Terraform requires a non-null bool there).
  enabled        = local.input.enabled == null ? local.defaults.enabled : local.input.enabled
  non_prd        = local.input.non_prd == null ? local.defaults.non_prd : local.input.non_prd
  prefix_enabled = local.input.prefix_enabled == null ? local.defaults.prefix_enabled : local.input.prefix_enabled
  delimiter      = local.input.delimiter == null ? local.defaults.delimiter : local.input.delimiter

  # deployment_region derived from aws_region when not set explicitly: split the
  # region on "-" and join <part0><first-letter-of-part1><part2>, so
  # us-west-2 -> usw2, eu-central-1 -> euc1, ap-northeast-1 -> apn1.
  aws_region_parts          = local.input.aws_region == null ? [] : split("-", local.input.aws_region)
  derived_deployment_region = local.input.aws_region == null ? null : "${local.aws_region_parts[0]}${substr(local.aws_region_parts[1], 0, 1)}${local.aws_region_parts[2]}"
  deployment_region         = local.input.deployment_region == null ? local.derived_deployment_region : local.input.deployment_region

  country = local.input.country == null ? "" : local.input.country
  stage   = local.input.stage == null ? "" : local.input.stage
  region  = local.deployment_region == null ? "" : local.deployment_region
  name    = local.input.name == null ? "" : local.input.name

  # Tag hierarchy segments (null -> "").
  project      = local.input.project == null ? "" : local.input.project
  application  = local.input.application == null ? "" : local.input.application
  module       = local.input.module == null ? "" : local.input.module
  stack_suffix = local.input.stack_suffix == null ? "" : local.input.stack_suffix

  # ohi:* hierarchy composes by nesting: project -> project-application ->
  # project-application-module; ohi:stack-name = <PREFIX>-<project>-<stack_suffix>.
  # application is emitted once there is an application or module segment (it
  # defaults to the project value, as the infra set does); module and stack-name
  # are only emitted when their own segment is set.
  ohi_project     = local.project
  ohi_application = (local.application == "" && local.module == "") ? "" : join(local.delimiter, compact([local.project, local.application]))
  ohi_module      = local.module == "" ? "" : join(local.delimiter, compact([local.project, local.application, local.module]))
  ohi_stack_name  = local.stack_suffix == "" ? "" : join(local.delimiter, compact([local.prefix, local.project, local.stack_suffix]))

  # PREFIX stage segment: <country><stage>, or <country>np when non_prd.
  stage_segment = local.non_prd ? (local.country == "" ? "" : "${local.country}np") : "${local.country}${local.stage}"

  # PREFIX = <stage_segment>-<deployment_region>, e.g. usstg-usw2 / usnp-usw2.
  prefix = join(local.delimiter, compact([local.stage_segment, local.region]))

  # id joins the non-empty segments with the delimiter, in order: <PREFIX>,
  # <name>, then <attributes...>. Following cloudposse null-label, `attributes`
  # is an independent segment emitted whenever present — compact() drops an
  # empty name, so attributes can appear without a name (e.g. `<PREFIX>-<attr>`
  # when a caller sets attributes but no name/context). prefix is omitted when
  # prefix_enabled = false.
  id_parts = local.prefix_enabled ? concat([local.prefix, local.name], local.input.attributes) : concat([local.name], local.input.attributes)
  id       = local.enabled ? join(local.delimiter, compact(local.id_parts)) : ""

  # Tag-key prefix (e.g. "ohi:"). Empty string yields unprefixed keys. Name is never prefixed.
  tag_prefix = local.input.tag_prefix == null ? "ohi:" : local.input.tag_prefix

  # Required OMRON tags (only emitted when non-empty), plus AWS Name = id.
  generated_tags_all = {
    "${local.tag_prefix}project"     = local.ohi_project
    "${local.tag_prefix}application" = local.ohi_application
    "${local.tag_prefix}module"      = local.ohi_module
    "${local.tag_prefix}stack-name"  = local.ohi_stack_name
    "${local.tag_prefix}environment" = local.prefix
    "Name"                           = local.id
  }
  generated_tags = { for k, v in local.generated_tags_all : k => v if v != null && v != "" }

  # Merge generated + user tags, then drop any empty-value entries so the module
  # never emits an empty tag value (applies the generated_tags filter to the whole map).
  tags = local.enabled ? { for k, v in merge(local.generated_tags, local.input.tags) : k => v if v != null && v != "" } : {}

  # Context to pass to child label modules. Carries the semantic fields and the
  # user-supplied tags only; each level re-derives ohi:*/Name from the fields.
  output_context = {
    enabled           = local.enabled
    country           = local.input.country
    stage             = local.input.stage
    aws_region        = local.input.aws_region
    deployment_region = local.input.deployment_region
    project           = local.input.project
    application       = local.input.application
    module            = local.input.module
    stack_suffix      = local.input.stack_suffix
    name              = local.input.name
    attributes        = local.input.attributes
    non_prd           = local.non_prd
    delimiter         = local.delimiter
    prefix_enabled    = local.prefix_enabled
    tag_prefix        = local.tag_prefix
    tags              = local.input.tags
  }
}
