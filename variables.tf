# OMRON null-label — wraps CloudPosse null-label for id/name generation and
# layers the OMRON (Voltron) Cloud Tagging Convention (ohi:* tags) on top.
#
# Every label field is optional so a parent label can set some fields and pass
# its `context` to child labels, which inherit the parent's values and override
# only what they need. Explicit variables always win over the inherited context;
# `attributes` and `tags` are merged (context first, then the explicit value).
#
# id shape (CloudPosse label_order): <namespace>-<region>-<stage>-<name>-<attributes>
#   e.g. cnct-uk-prd-mobile-api
#   - namespace : product token (cnct/crt/luscii) — REQUIRED (var or context)
#   - region    : logical region (us/eu/uk), linked to an AWS region
#   - stage     : dev/qa/stg/prd, or "np" when non_prd = true
#   - name      : composed <application>-<name> leaf hierarchy
# The AWS region is NOT part of the id — it is emitted as the ohi:aws-region tag.

variable "context" {
  description = "Inherited label context from a parent module invocation. Explicit variables override matching context fields; attributes and tags are merged."
  type = object({
    enabled              = optional(bool, true)
    namespace            = optional(string, null)
    region               = optional(string, null)
    stage                = optional(string, null)
    aws_region           = optional(string, null)
    application          = optional(string, null)
    module               = optional(string, null)
    stack_suffix         = optional(string, null)
    stack_name_enabled   = optional(bool, true)
    owner                = optional(string, null)
    name                 = optional(string, null)
    attributes           = optional(list(string), [])
    non_prd              = optional(bool, false)
    delimiter            = optional(string, "-")
    tag_prefix           = optional(string, "ohi")
    tag_delimiter        = optional(string, ":")
    id_length_limit      = optional(number, null)
    max_tag_key_length   = optional(number, null)
    max_tag_value_length = optional(number, null)
    tags                 = optional(map(string), {})
  })
  default = {}
}

variable "enabled" {
  description = "Set to false to produce an empty id and no tags."
  type        = bool
  default     = null
}

# --- id segments: <namespace>-<region>-<stage> ---

variable "namespace" {
  description = "Product namespace and leading id segment, e.g. cnct (Connect), crt (Create), luscii. REQUIRED: must resolve from this variable or the inherited context when enabled."
  type        = string
  default     = null
}

variable "region" {
  description = "Logical region code (the geo identifier in the id), e.g. us, eu, uk. Each logical region maps to an AWS region (us->us-east-1, eu->eu-central-1, uk->eu-west-2) and is extensible. This is NOT the AWS region code — set aws_region for that."
  type        = string
  default     = null
}

variable "stage" {
  description = "Stage code, e.g. dev, qa, stg, prd. Becomes \"np\" in the id/Stage tag when non_prd = true."
  type        = string
  default     = null

  validation {
    condition     = var.stage == null ? true : contains(["dev", "qa", "stg", "prd"], var.stage)
    error_message = "The stage must be one of: dev, qa, stg, prd."
  }
}

variable "non_prd" {
  description = "When true, the stage segment becomes \"np\" so resources shared across the non-prod stages (dev/qa/stg) carry a single non-prod stage."
  type        = bool
  default     = null
}

variable "aws_region" {
  description = "AWS region code, e.g. us-east-1, eu-central-1, eu-west-2. Emitted as the ohi:aws-region tag; NOT part of the id (through account navigation the AWS region is already a given)."
  type        = string
  default     = null

  validation {
    condition     = var.aws_region == null ? true : can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "The aws_region must be a valid AWS region code, e.g. us-east-1, eu-central-1, eu-west-2."
  }
}

# --- Tag hierarchy (under the namespace/product) ---
# `namespace` is the product identity (e.g. cnct = Connect/voltron), emitted as
# CloudPosse's Namespace tag — there is no separate `project` field. Below it:
# ohi:application = <application>; ohi:module = <application>-<module>. The
# <application>-<name> leaf feeds CloudPosse's `name` component, so `application`
# appears in the id; `module` does not (it lives only in the ohi:module tag).

variable "application" {
  description = "Application segment under the namespace, e.g. \"mobile\" -> ohi:application = mobile, and the leading part of the id name (cnct-uk-prd-mobile-...). Leave empty for namespace-level (e.g. shared infra)."
  type        = string
  default     = null
}

variable "module" {
  description = "Module segment appended to application to form ohi:module (e.g. \"be\" under application \"mobile\" -> mobile-be). Not part of the id."
  type        = string
  default     = null
}

variable "stack_suffix" {
  description = "OPTIONAL override for ohi:stack-name. By default ohi:stack-name is <namespace>-<region>-<stage>-<deepest hierarchy> (module, else application). Set it only to pin an exact leaf when something external depends on a specific stack name."
  type        = string
  default     = null
}

variable "stack_name_enabled" {
  description = "When true (default) the ohi:stack-name tag is emitted. Set to false to drop the tag for labels where a stack name is not meaningful. Inherited by child labels via context; null inherits from context."
  type        = bool
  default     = null
}

# --- Ownership ---

variable "owner" {
  description = "The circle that controls the resource. Emitted as the ohi:owner tag (subject to tag_prefix/tag_delimiter). Not part of the id."
  type        = string
  default     = null
}

variable "owner_propagation_enabled" {
  description = "When true (default) owner is carried into the exported context, so child labels inherit it. Set to false to withhold owner from the context: this label still emits its own ohi:owner tag, but child labels start without an owner and must state their own explicitly. This is a ONE-LEVEL ownership reset: the toggle itself is NOT part of the context and does not travel. null means the default (true)."
  type        = bool
  default     = null
}

# --- Name generation ---

variable "name" {
  description = "The leaf resource name. The id composes <namespace>-<region>-<stage>-<application>-<name>, so keep it short (e.g. namespace=cnct, application=mobile, name=\"api\" -> cnct-uk-prd-mobile-api)."
  type        = string
  default     = null
}

variable "attributes" {
  description = "Ordered list of extra attributes appended to the id. Merged onto any inherited from context."
  type        = list(string)
  default     = null
}

variable "delimiter" {
  description = "Delimiter between id and tag-hierarchy segments. null inherits from context (defaults to \"-\")."
  type        = string
  default     = null
}

variable "tag_prefix" {
  description = "Prefix segment prepended to the generated OMRON tag keys, joined to the key by tag_delimiter (e.g. \"ohi\" + \":\" produces ohi:application). Set to \"\" for unprefixed keys. null inherits from context (defaults to \"ohi\"). CloudPosse's Namespace/Environment/Stage/Name tags are unaffected. Must not resolve to the reserved \"aws:\" prefix."
  type        = string
  default     = null

  validation {
    condition     = var.tag_prefix == null ? true : lower(var.tag_prefix) != "aws"
    error_message = "Do not use AWS: or any upper or lowercase combination of such as a prefix for either keys or values. These are reserved only for AWS use."
  }
  validation {
    condition     = var.tag_prefix == null ? true : can(regex("^[\\p{L}\\p{N} _.:/=+@-]*$", var.tag_prefix))
    error_message = "The tag_prefix may only contain letters, numbers, spaces and _ . : / = + - @ (the characters AWS allows in tag keys)."
  }
}

variable "tag_delimiter" {
  description = "Delimiter between tag key segments (e.g. \":\" produces ohi:application). null inherits from context (defaults to \":\")."
  type        = string
  default     = null

  validation {
    condition     = var.tag_delimiter == null ? true : can(regex("^[\\p{L}\\p{N} _.:/=+@-]*$", var.tag_delimiter))
    error_message = "The tag_delimiter may only contain letters, numbers, spaces and _ . : / = + - @ (the characters AWS allows in tag keys)."
  }
}

variable "id_length_limit" {
  description = "Limit the generated id to at most this many characters (forwarded to CloudPosse null-label). When the full id is longer, the leading characters are kept and a short hash is appended so distinct ids stay unique. Set to 0 for unlimited length (default), or null to inherit from context. Minimum 6 when set."
  type        = number
  default     = null

  validation {
    condition     = var.id_length_limit == null ? true : (var.id_length_limit == 0 || var.id_length_limit >= 6)
    error_message = "The id_length_limit must be >= 6 when set, or 0 for unlimited length."
  }
}

variable "max_tag_key_length" {
  description = "Maximum tag key length in Unicode characters. Defaults to the AWS ceiling of 128; lower it for services with tighter restrictions. Inherited via context. Keys longer than this raise an error."
  type        = number
  default     = null

  validation {
    condition     = var.max_tag_key_length == null ? true : (var.max_tag_key_length >= 1 && var.max_tag_key_length <= 128)
    error_message = "The max_tag_key_length must be between 1 and 128 (the AWS ceiling)."
  }
}

variable "max_tag_value_length" {
  description = "Maximum tag value length in Unicode characters. Defaults to the AWS ceiling of 256; lower it for services with tighter restrictions. Inherited via context. Values longer than this are truncated to (limit - 5) characters plus a 5-char hash."
  type        = number
  default     = null

  validation {
    condition     = var.max_tag_value_length == null ? true : (var.max_tag_value_length >= 6 && var.max_tag_value_length <= 256)
    error_message = "The max_tag_value_length must be between 6 and 256 (the AWS ceiling), leaving room for the 5-char truncation hash."
  }
}

variable "tags" {
  description = "Additional tags merged with the generated CloudPosse + ohi:* tags. On a key collision the GENERATED tags win, so the standard keys (Namespace, Environment, Stage, Name, ohi:*) cannot be overridden or cleared. AWS counts the generated tags toward its 50-tag cap, so the final emitted map (generated + additional) may hold at most 50 entries. Keys at most max_tag_key_length (default 128) and values at most max_tag_value_length (default 256) Unicode characters. Keys and values may only contain letters, numbers, spaces and _ . : / = + - @."
  type        = map(string)
  default     = {}
}
