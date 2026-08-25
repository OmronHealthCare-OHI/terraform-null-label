locals {
  defaults = {
    enabled                   = true
    non_prd                   = false
    stack_name_enabled        = true
    owner_propagation_enabled = true
    delimiter                 = "-"
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
    enabled            = var.enabled == null ? var.context.enabled : var.enabled
    namespace          = var.namespace == null ? var.context.namespace : var.namespace
    region             = var.region == null ? var.context.region : var.region
    stage              = var.stage == null ? var.context.stage : var.stage
    aws_region         = var.aws_region == null ? var.context.aws_region : var.aws_region
    application        = var.application == null ? var.context.application : var.application
    module             = var.module == null ? var.context.module : var.module
    stack_suffix       = var.stack_suffix == null ? var.context.stack_suffix : var.stack_suffix
    stack_name_enabled = var.stack_name_enabled == null ? var.context.stack_name_enabled : var.stack_name_enabled
    owner              = var.owner == null ? var.context.owner : var.owner
    # Deliberately NOT read from context: owner_propagation_enabled is a
    # one-level ownership reset. It is not part of the context object, so a
    # parent's reset can never silently disable owner propagation for a child.
    owner_propagation_enabled = var.owner_propagation_enabled
    name                      = var.name == null ? var.context.name : var.name
    non_prd                   = var.non_prd == null ? var.context.non_prd : var.non_prd
    delimiter                 = var.delimiter == null ? var.context.delimiter : var.delimiter
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
  stack_name_enabled        = local.input.stack_name_enabled == null ? local.defaults.stack_name_enabled : local.input.stack_name_enabled
  owner_propagation_enabled = local.input.owner_propagation_enabled == null ? local.defaults.owner_propagation_enabled : local.input.owner_propagation_enabled
  delimiter                 = local.input.delimiter == null ? local.defaults.delimiter : local.input.delimiter
  id_length_limit           = local.input.id_length_limit == null ? local.defaults.id_length_limit : local.input.id_length_limit
  id_hash_length            = local.defaults.id_hash_length
  max_tag_key_length        = local.input.max_tag_key_length == null ? local.defaults.max_tag_key_length : local.input.max_tag_key_length
  max_tag_value_length      = local.input.max_tag_value_length == null ? local.defaults.max_tag_value_length : local.input.max_tag_value_length

  # id/tag segments (null -> "").
  namespace    = local.input.namespace == null ? "" : local.input.namespace
  region       = local.input.region == null ? "" : local.input.region
  stage        = local.input.stage == null ? "" : local.input.stage
  aws_region   = local.input.aws_region == null ? "" : local.input.aws_region
  name         = local.input.name == null ? "" : local.input.name
  application  = local.input.application == null ? "" : local.input.application
  module       = local.input.module == null ? "" : local.input.module
  stack_suffix = local.input.stack_suffix == null ? "" : local.input.stack_suffix
  owner        = local.input.owner == null ? "" : local.input.owner

  # Stage segment: "np" collapses the non-prod stages into one; otherwise stage.
  stage_segment = local.non_prd ? "np" : local.stage

  # Tag-key prefix + delimiter (e.g. "ohi" + ":" -> "ohi:application"). Coalesce a
  # null (via var or context) to the default. An empty tag_prefix drops the
  # prefix segment, yielding unprefixed keys.
  tag_prefix    = local.input.tag_prefix == null ? "ohi" : local.input.tag_prefix
  tag_delimiter = local.input.tag_delimiter == null ? ":" : local.input.tag_delimiter

  # ohi:* hierarchy under the namespace (product): application -> application-module.
  # `namespace` is the product identity (CloudPosse Namespace) — there is no
  # separate ohi:project (it would double the Namespace tag). application feeds
  # CloudPosse's `name` component so it appears in the id; module does not (it
  # lives only in ohi:module).
  hierarchy_application = local.application
  hierarchy_module      = local.module == "" ? "" : join(local.delimiter, compact([local.application, local.module]))

  # The leaf hierarchy handed to CloudPosse as its `name` component:
  # <application>-<name> (module excluded).
  cp_name = join(local.delimiter, compact([local.application, local.name]))

  # ohi:stack-name identifies the concrete deployed stack:
  # <namespace>-<region>-<stage>-<deepest set hierarchy> (module, else
  # application) — e.g. cnct-uk-prd-mobile-be. stack_suffix pins the leaf when
  # something external needs an exact value.
  stack_hierarchy = local.module != "" ? local.hierarchy_module : local.hierarchy_application
  stack_identity  = local.stack_suffix != "" ? local.stack_suffix : local.stack_hierarchy
  stack_prefix    = join(local.delimiter, compact([local.namespace, local.region, local.stage_segment]))
  stack_name      = local.stack_identity == "" ? "" : join(local.delimiter, compact([local.stack_prefix, local.stack_identity]))

  # OMRON ohi:* tags (only emitted when non-empty). CloudPosse emits
  # Namespace/Environment/Stage/Name; these are the OMRON-specific additions.
  ohi_tags_all = {
    (join(local.tag_delimiter, compact([local.tag_prefix, "application"]))) = local.hierarchy_application
    (join(local.tag_delimiter, compact([local.tag_prefix, "module"])))      = local.hierarchy_module
    (join(local.tag_delimiter, compact([local.tag_prefix, "stack-name"])))  = local.stack_name_enabled ? local.stack_name : ""
    (join(local.tag_delimiter, compact([local.tag_prefix, "owner"])))       = local.owner
    (join(local.tag_delimiter, compact([local.tag_prefix, "aws-region"])))  = local.aws_region
  }
  ohi_tags = { for k, v in local.ohi_tags_all : k => v if v != null && v != "" }

  # Merge CloudPosse's standard tags (Namespace/Environment/Stage/Name) with the
  # ohi:* tags and the user tags, then drop empty-value entries.
  tags_raw = local.enabled ? { for k, v in merge(module.cloudposse_label.tags, local.ohi_tags, local.input.tags) : k => v if v != null && v != "" } : {}

  # Cap tag values at max_tag_value_length Unicode characters: over-long values
  # are truncated to (limit - hash) characters plus a short md5 hash of the
  # original, so distinct long values stay distinct.
  tags = { for k, v in local.tags_raw : k => length(v) > local.max_tag_value_length ? "${substr(v, 0, local.max_tag_value_length - local.id_hash_length)}${substr(md5(v), 0, local.id_hash_length)}" : v }

  # Tag-constraint validation helpers (surfaced as output preconditions). Keys
  # are checked on the final (emitted) set; values on tags_raw so an invalid
  # character anywhere in a long value is caught before truncation.
  tag_keys             = keys(local.tags)
  oversized_tag_keys   = [for k in local.tag_keys : k if length(k) > local.max_tag_key_length]
  has_empty_tag_key    = contains(local.tag_keys, "")
  invalid_char_keys    = [for k in local.tag_keys : k if !can(regex(local.tag_allowed_chars_regex, k))]
  reserved_prefix_keys = [for k in local.tag_keys : k if substr(lower(k), 0, 4) == "aws:"]
  invalid_value_keys   = [for k, v in local.tags_raw : k if !can(regex(local.tag_allowed_chars_regex, v))]
  # Count only non-empty user tags: empty-valued entries are dropped and never
  # emitted, so they must not count toward the 50-tag limit.
  user_tag_count = length([for k, v in local.input.tags : k if v != null && v != ""])

  # namespace is required (via variable or context) when the label is enabled —
  # CloudPosse's id and Namespace tag both depend on it. Surfaced as the id
  # precondition.
  namespace_present = !local.enabled || local.namespace != ""

  # Context to pass to child label modules. Carries the semantic fields and the
  # user-supplied tags only; each level re-derives CloudPosse id + ohi:*/Name
  # from the fields. owner is withheld (null) when owner_propagation_enabled =
  # false, so child labels do not silently adopt the parent's owner.
  output_context = {
    enabled              = local.enabled
    namespace            = local.input.namespace
    region               = local.input.region
    stage                = local.input.stage
    aws_region           = local.input.aws_region
    application          = local.input.application
    module               = local.input.module
    stack_suffix         = local.input.stack_suffix
    stack_name_enabled   = local.stack_name_enabled
    owner                = local.owner_propagation_enabled ? local.input.owner : null
    name                 = local.input.name
    attributes           = local.input.attributes
    non_prd              = local.non_prd
    delimiter            = local.delimiter
    tag_prefix           = local.tag_prefix
    tag_delimiter        = local.tag_delimiter
    id_length_limit      = local.id_length_limit
    max_tag_key_length   = local.max_tag_key_length
    max_tag_value_length = local.max_tag_value_length
    tags                 = local.input.tags
  }
}

# CloudPosse null-label generates the resource id/Name and the standard
# Namespace/Environment/Stage/Name tags. OMRON wraps it: this module maps the
# OMRON semantic fields onto CloudPosse's label components and layers the ohi:*
# tags on top. id shape: <namespace>-<region>-<stage>-<name>-<attributes>.
module "cloudposse_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled     = local.enabled
  namespace   = local.namespace
  environment = local.region
  stage       = local.stage_segment
  name        = local.cp_name
  attributes  = local.input.attributes
  delimiter   = local.delimiter

  # <namespace>-<region>-<stage>-<name>-<attributes>. region -> environment,
  # stage_segment -> stage. tenant is unused.
  label_order     = ["namespace", "environment", "stage", "name", "attributes"]
  id_length_limit = local.id_length_limit
}
