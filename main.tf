locals {
  defaults = {
    delimiter                 = "-"
    enabled                   = true
    non_prd                   = false
    prefix_enabled            = true
    stack_name_enabled        = true
    owner_propagation_enabled = true
    id_length_limit           = 0
    id_hash_length            = 5
    max_tag_key_length        = 128
    max_tag_value_length      = 256
  }

  # AWS tag constraints — see
  # https://docs.aws.amazon.com/tag-editor/latest/userguide/reference.html
  # AWS caps user-created tags at 50 per resource (AWS-generated tags don't
  # count). The key/value length ceilings default to the AWS maxima (128/256)
  # but are configurable because some services are stricter — resolved below.
  max_user_tags = 50

  # Characters AWS permits in tag keys and values: letters, numbers, spaces and
  # _ . : / = + - @ (length is still counted in Unicode characters).
  tag_allowed_chars_regex = "^[\\p{L}\\p{N} _.:/=+@-]*$"

  # Explicit variables override the inherited context (null = inherit).
  # attributes and tags are merged (context first, then explicit value).
  input = {
    enabled                   = var.enabled == null ? var.context.enabled : var.enabled
    country                   = var.country == null ? var.context.country : var.country
    stage                     = var.stage == null ? var.context.stage : var.stage
    aws_region                = var.aws_region == null ? var.context.aws_region : var.aws_region
    deployment_region         = var.deployment_region == null ? var.context.deployment_region : var.deployment_region
    project                   = var.project == null ? var.context.project : var.project
    application               = var.application == null ? var.context.application : var.application
    module                    = var.module == null ? var.context.module : var.module
    stack_suffix              = var.stack_suffix == null ? var.context.stack_suffix : var.stack_suffix
    stack_name_enabled        = var.stack_name_enabled == null ? var.context.stack_name_enabled : var.stack_name_enabled
    owner                     = var.owner == null ? var.context.owner : var.owner
    owner_propagation_enabled = var.owner_propagation_enabled == null ? var.context.owner_propagation_enabled : var.owner_propagation_enabled
    name                      = var.name == null ? var.context.name : var.name
    non_prd                   = var.non_prd == null ? var.context.non_prd : var.non_prd
    delimiter                 = var.delimiter == null ? var.context.delimiter : var.delimiter
    prefix_enabled            = var.prefix_enabled == null ? var.context.prefix_enabled : var.prefix_enabled
    tag_prefix                = var.tag_prefix == null ? var.context.tag_prefix : var.tag_prefix
    tag_delimiter             = var.tag_delimiter == null ? var.context.tag_delimiter : var.tag_delimiter
    id_length_limit           = var.id_length_limit == null ? var.context.id_length_limit : var.id_length_limit
    max_tag_key_length        = var.max_tag_key_length == null ? var.context.max_tag_key_length : var.max_tag_key_length
    max_tag_value_length      = var.max_tag_value_length == null ? var.context.max_tag_value_length : var.max_tag_value_length
    attributes                = compact(distinct(concat(coalesce(var.context.attributes, []), coalesce(var.attributes, []))))
    tags                      = merge(coalesce(var.context.tags, {}), coalesce(var.tags, {}))
  }

  # Coalesce to defaults so an explicit null (as a variable or via context) can't
  # break the conditionals below (Terraform requires a non-null bool there).
  enabled                   = local.input.enabled == null ? local.defaults.enabled : local.input.enabled
  non_prd                   = local.input.non_prd == null ? local.defaults.non_prd : local.input.non_prd
  prefix_enabled            = local.input.prefix_enabled == null ? local.defaults.prefix_enabled : local.input.prefix_enabled
  stack_name_enabled        = local.input.stack_name_enabled == null ? local.defaults.stack_name_enabled : local.input.stack_name_enabled
  owner_propagation_enabled = local.input.owner_propagation_enabled == null ? local.defaults.owner_propagation_enabled : local.input.owner_propagation_enabled
  delimiter                 = local.input.delimiter == null ? local.defaults.delimiter : local.input.delimiter

  # deployment_region derived from aws_region when not set explicitly: split the
  # region on "-" and join <part0><first-letter-of-part1><part2>, so
  # us-west-2 -> usw2, eu-central-1 -> euc1, ap-northeast-1 -> apn1.
  aws_region_parts          = local.input.aws_region == null ? [] : split("-", local.input.aws_region)
  derived_deployment_region = local.input.aws_region == null ? null : "${local.aws_region_parts[0]}${substr(local.aws_region_parts[1], 0, 1)}${local.aws_region_parts[2]}"
  deployment_region         = local.input.deployment_region == null ? local.derived_deployment_region : local.input.deployment_region

  # 0 = unlimited id length. Coalesce a null (via var or context) to the default.
  id_length_limit = local.input.id_length_limit == null ? local.defaults.id_length_limit : local.input.id_length_limit
  id_hash_length  = local.defaults.id_hash_length

  # Tag length ceilings, coalesced to the AWS maxima when unset.
  max_tag_key_length   = local.input.max_tag_key_length == null ? local.defaults.max_tag_key_length : local.input.max_tag_key_length
  max_tag_value_length = local.input.max_tag_value_length == null ? local.defaults.max_tag_value_length : local.input.max_tag_value_length

  country = local.input.country == null ? "" : local.input.country
  stage   = local.input.stage == null ? "" : local.input.stage
  region  = local.deployment_region == null ? "" : local.deployment_region
  name    = local.input.name == null ? "" : local.input.name

  # Tag hierarchy segments (null -> "").
  project      = local.input.project == null ? "" : local.input.project
  application  = local.input.application == null ? "" : local.input.application
  module       = local.input.module == null ? "" : local.input.module
  stack_suffix = local.input.stack_suffix == null ? "" : local.input.stack_suffix
  owner        = local.input.owner == null ? "" : local.input.owner

  # ohi:* hierarchy composes by nesting: project -> project-application ->
  # project-application-module. application is emitted once there is an
  # application or module segment (it defaults to the project value, as the infra
  # set does); module is only emitted when its own segment is set. These are the
  # tag *values*; the tag-key prefix is configurable via tag_prefix.
  hierarchy_project     = local.project
  hierarchy_application = (local.application == "" && local.module == "") ? "" : join(local.delimiter, compact([local.project, local.application]))
  hierarchy_module      = local.module == "" ? "" : join(local.delimiter, compact([local.project, local.application, local.module]))

  # stack-name identifies the concrete deployed stack: <PREFIX>-<deepest set
  # hierarchy> (module, else application, else project) — e.g. usstg-usw2-vlt-mobile-be.
  # stack_suffix is an OPTIONAL escape hatch to pin an exact value
  # (<PREFIX>-<stack_suffix>) when something external needs it; it is NOT required
  # for normal use and can be dropped from the module if nobody relies on it.
  stack_hierarchy = local.module != "" ? local.hierarchy_module : (local.application != "" ? local.hierarchy_application : local.hierarchy_project)
  stack_identity  = local.stack_suffix != "" ? local.stack_suffix : local.stack_hierarchy
  stack_name      = local.stack_identity == "" ? "" : join(local.delimiter, compact([local.prefix, local.stack_identity]))

  # PREFIX stage segment: <country><stage>, or <country>np when non_prd.
  stage_segment = local.non_prd ? (local.country == "" ? "" : "${local.country}np") : "${local.country}${local.stage}"

  # PREFIX = <stage_segment>-<deployment_region>, e.g. usstg-usw2 / usnp-usw2.
  prefix = join(local.delimiter, compact([local.stage_segment, local.region]))

  # id composes the inherited hierarchy in front of the leaf name so `name` stays
  # short: <PREFIX>-<project>-<application>-<name>-<attributes...>. `module` is
  # intentionally excluded — it lives in the ohi:module tag, not the id. compact()
  # drops empty segments, so a nameless label still yields <PREFIX>-<hierarchy>,
  # and attributes can appear without a name (CloudPosse null-label parity). The
  # prefix is omitted when prefix_enabled = false.
  id_parts = local.prefix_enabled ? concat([local.prefix, local.project, local.application, local.name], local.input.attributes) : concat([local.project, local.application, local.name], local.input.attributes)
  id_full  = local.enabled ? join(local.delimiter, compact(local.id_parts)) : ""

  # id truncation (CloudPosse null-label parity): when id_length_limit is set
  # (non-zero) and id_full exceeds it, keep the leading characters (leaving room
  # for a trailing delimiter + hash) and append a short md5 hash of id_full so
  # distinct long ids stay distinct.
  delimiter_length          = length(local.delimiter)
  id_truncated_length_limit = local.id_length_limit - (local.id_hash_length + local.delimiter_length)
  id_truncated              = local.id_truncated_length_limit <= 0 ? "" : "${trimsuffix(substr(local.id_full, 0, local.id_truncated_length_limit), local.delimiter)}${local.delimiter}"
  id_hash                   = substr(md5(local.id_full), 0, local.id_hash_length)
  id_short                  = substr("${local.id_truncated}${local.id_hash}", 0, local.id_length_limit)
  id                        = local.id_length_limit != 0 && length(local.id_full) > local.id_length_limit ? local.id_short : local.id_full

  # Tag-key prefix + delimiter (e.g. "ohi" + ":" -> "ohi:project"). Coalesce a
  # null (via var or context) to the default so compact() never sees a null.
  # An empty tag_prefix drops the prefix segment, yielding unprefixed keys.
  tag_prefix    = local.input.tag_prefix == null ? "ohi" : local.input.tag_prefix
  tag_delimiter = local.input.tag_delimiter == null ? ":" : local.input.tag_delimiter

  # Required OMRON tags (only emitted when non-empty), plus the AWS Name tag.
  # Name carries the full id (id_length_limit governs the id output for resource
  # identifiers; as a tag, Name is bound only by the tag-value limit applied below).
  generated_tags_all = {
    (join(local.tag_delimiter, compact([local.tag_prefix, "project"])))     = local.hierarchy_project
    (join(local.tag_delimiter, compact([local.tag_prefix, "application"]))) = local.hierarchy_application
    (join(local.tag_delimiter, compact([local.tag_prefix, "module"])))      = local.hierarchy_module
    (join(local.tag_delimiter, compact([local.tag_prefix, "stack-name"])))  = local.stack_name_enabled ? local.stack_name : ""
    (join(local.tag_delimiter, compact([local.tag_prefix, "environment"]))) = local.prefix
    (join(local.tag_delimiter, compact([local.tag_prefix, "owner"])))       = local.owner
    "Name"                                                                  = local.id_full
  }
  generated_tags = { for k, v in local.generated_tags_all : k => v if v != null && v != "" }

  # Merge generated + user tags, then drop any empty-value entries so the module
  # never emits an empty tag value (applies the generated_tags filter to the whole map).
  tags_raw = local.enabled ? { for k, v in merge(local.generated_tags, local.input.tags) : k => v if v != null && v != "" } : {}

  # Cap tag values at max_tag_value_length Unicode characters: over-long values
  # are truncated to (limit - hash) characters plus a short md5 hash of the
  # original, mirroring the id truncation so distinct long values stay distinct.
  tags = { for k, v in local.tags_raw : k => length(v) > local.max_tag_value_length ? "${substr(v, 0, local.max_tag_value_length - local.id_hash_length)}${substr(md5(v), 0, local.id_hash_length)}" : v }

  # Tag-constraint validation helpers (surfaced as output preconditions). Keys are
  # checked on the final (emitted) set; values are checked on tags_raw so an
  # invalid character anywhere in a long value is caught before truncation.
  tag_keys             = keys(local.tags)
  oversized_tag_keys   = [for k in local.tag_keys : k if length(k) > local.max_tag_key_length]
  has_empty_tag_key    = contains(local.tag_keys, "")
  invalid_char_keys    = [for k in local.tag_keys : k if !can(regex(local.tag_allowed_chars_regex, k))]
  reserved_prefix_keys = [for k in local.tag_keys : k if substr(lower(k), 0, 4) == "aws:"]
  invalid_value_keys   = [for k, v in local.tags_raw : k if !can(regex(local.tag_allowed_chars_regex, v))]
  # Count only non-empty user tags: empty-valued entries are dropped and never
  # emitted, so they must not count toward the 50-tag limit.
  user_tag_count = length([for k, v in local.input.tags : k if v != null && v != ""])

  # Context to pass to child label modules. Carries the semantic fields and the
  # user-supplied tags only; each level re-derives ohi:*/Name from the fields.
  # owner is withheld (null) when owner_propagation_enabled = false, so child
  # labels do not silently adopt the parent's owner and must state their own.
  output_context = {
    enabled                   = local.enabled
    country                   = local.input.country
    stage                     = local.input.stage
    aws_region                = local.input.aws_region
    deployment_region         = local.input.deployment_region
    project                   = local.input.project
    application               = local.input.application
    module                    = local.input.module
    stack_suffix              = local.input.stack_suffix
    stack_name_enabled        = local.stack_name_enabled
    owner                     = local.owner_propagation_enabled ? local.input.owner : null
    owner_propagation_enabled = local.owner_propagation_enabled
    name                      = local.input.name
    attributes                = local.input.attributes
    non_prd                   = local.non_prd
    delimiter                 = local.delimiter
    prefix_enabled            = local.prefix_enabled
    tag_prefix                = local.tag_prefix
    tag_delimiter             = local.tag_delimiter
    id_length_limit           = local.id_length_limit
    max_tag_key_length        = local.max_tag_key_length
    max_tag_value_length      = local.max_tag_value_length
    tags                      = local.input.tags
  }
}
