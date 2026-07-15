# OMRON null-label — CloudPosse-null-label-style labeling that follows the
# OMRON (Voltron) Cloud Tagging Convention.
#
# Every label field is optional so a parent label can set some fields and pass
# its `context` to child labels, which inherit the parent's values and override
# only what they need. Explicit variables always win over the inherited context;
# `attributes` and `tags` are merged (context first, then the explicit value).

variable "context" {
  description = "Inherited label context from a parent module invocation. Explicit variables override matching context fields; attributes and tags are merged."
  type = object({
    enabled              = optional(bool, true)
    country              = optional(string, null)
    stage                = optional(string, null)
    aws_region           = optional(string, null)
    deployment_region    = optional(string, null)
    project              = optional(string, null)
    application          = optional(string, null)
    module               = optional(string, null)
    stack_suffix         = optional(string, null)
    owner                = optional(string, null)
    name                 = optional(string, null)
    attributes           = optional(list(string), [])
    non_prd              = optional(bool, false)
    delimiter            = optional(string, "-")
    prefix_enabled       = optional(bool, true)
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

# --- PREFIX parts: <country><stage>-<deployment_region>, e.g. usstg-usw2 ---

variable "country" {
  description = "Country code, e.g. us, eu, jp, in, sg, br."
  type        = string
  default     = null
}

variable "stage" {
  description = "Stage code, e.g. dev, qa, stg, prd. Ignored for the stage segment when non_prd = true."
  type        = string
  default     = null

  validation {
    condition     = var.stage == null || contains(["dev", "qa", "stg", "prd"], var.stage)
    error_message = "The stage must be one of: dev, qa, stg, prd."
  }
}

variable "aws_region" {
  description = "AWS region code, e.g. us-west-2, eu-west-1, ap-northeast-1. When deployment_region is not set, the PREFIX region segment is derived from this value."
  type        = string
  default     = null

  validation {
    condition     = var.aws_region == null || can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "The aws_region must be a valid AWS region code, e.g. us-west-2, eu-central-1, ap-northeast-1."
  }
}

variable "deployment_region" {
  description = "Deployment region short code, e.g. usw2, euw1, apn1. Overwrites the AWS region code for the PREFIX segment. When null, it is derived from aws_region."
  type        = string
  default     = null
}

variable "non_prd" {
  description = "When true, the stage segment becomes <country>np (e.g. usnp) so resources shared across the non-prod stages (dev/qa/stg) carry a single non-prod stage."
  type        = bool
  default     = null
}

# --- Tag hierarchy (composed by nesting) ---
# The ohi:* values nest: ohi:project = <project>; ohi:application =
# <project>-<application>; ohi:module = <project>-<application>-<module>;
# ohi:stack-name = <PREFIX>-<project>-<stack_suffix>. Each segment is optional
# (empty segments are dropped), so the default/infra set is `project=vlt,
# application="", module="infra"` -> ohi:application=vlt, ohi:module=vlt-infra.

variable "project" {
  description = "Top of the tag hierarchy and the leading segment of every ohi:* value, e.g. vlt, common."
  type        = string
  default     = null
}

variable "application" {
  description = "Application segment appended to project to form ohi:application (e.g. \"mobile\" -> vlt-mobile). Leave empty when the application equals the project (e.g. the infra set)."
  type        = string
  default     = null
}

variable "module" {
  description = "Module segment appended to form ohi:module (e.g. \"be\" -> vlt-mobile-be, \"infra\" -> vlt-infra)."
  type        = string
  default     = null
}

variable "stack_suffix" {
  description = "Suffix appended to <PREFIX>-<project> to form ohi:stack-name (e.g. \"be-serverless-stack\" -> usstg-usw2-vlt-be-serverless-stack)."
  type        = string
  default     = null
}

# --- Ownership ---

variable "owner" {
  description = "The circle that controls the resource. Emitted as the ohi:owner tag (subject to tag_prefix/tag_delimiter). Not part of the id or the ohi:* naming hierarchy."
  type        = string
  default     = null
}

# --- Name generation ---

variable "name" {
  description = "The resource name appended after the PREFIX to form the id (e.g. vlt-mobile-api)."
  type        = string
  default     = null
}

variable "attributes" {
  description = "Ordered list of extra attributes appended to the id. Following CloudPosse null-label, attributes is an independent segment emitted whenever present — it can appear even without a name (e.g. <PREFIX>-<attr>). Merged onto any inherited from context."
  type        = list(string)
  default     = null
}

variable "prefix_enabled" {
  description = "When true (default) the generated id is prefixed with the PREFIX. Set to false for resources that must not carry the prefix."
  type        = bool
  default     = null
}

variable "delimiter" {
  description = "Delimiter between id segments."
  type        = string
  default     = null
}

variable "tag_prefix" {
  description = "Prefix segment prepended to the generated tag keys, joined to the key by tag_delimiter (e.g. \"ohi\" + \":\" produces ohi:project). Set to \"\" for unprefixed keys (project, application, …). null inherits from context (defaults to \"ohi\"). The Name tag is never prefixed. Must not resolve to the reserved \"aws:\" prefix."
  type        = string
  default     = null

  validation {
    condition     = var.tag_prefix == null || lower(var.tag_prefix) != "aws"
    error_message = "Do not use AWS: or any upper or lowercase combination of such as a prefix for either keys or values. These are reserved only for AWS use."
  }
  validation {
    condition     = var.tag_prefix == null || can(regex("^[\\p{L}\\p{N} _.:/=+@-]*$", var.tag_prefix))
    error_message = "The tag_prefix may only contain letters, numbers, spaces and _ . : / = + - @ (the characters AWS allows in tag keys)."
  }
}

variable "tag_delimiter" {
  description = "Delimiter between tag key segments (e.g. \":\" produces ohi:project). null inherits from context (defaults to \":\"). The Name tag is never affected by this setting."
  type        = string
  default     = null

  validation {
    condition     = var.tag_delimiter == null || can(regex("^[\\p{L}\\p{N} _.:/=+@-]*$", var.tag_delimiter))
    error_message = "The tag_delimiter may only contain letters, numbers, spaces and _ . : / = + - @ (the characters AWS allows in tag keys)."
  }
}

variable "id_length_limit" {
  description = "Limit the generated id (and the Name tag) to at most this many characters. When the full id is longer, it is truncated and a short md5 hash is appended to keep it unique (CloudPosse null-label parity). Set to 0 for unlimited length (default), or null to inherit from context. Minimum 6 when set. Does not affect the id segments carried in context."
  type        = number
  default     = null

  validation {
    condition     = var.id_length_limit == null || var.id_length_limit == 0 || var.id_length_limit >= 6
    error_message = "The id_length_limit must be >= 6 when set, or 0 for unlimited length."
  }
}

variable "max_tag_key_length" {
  description = "Maximum tag key length in Unicode characters. Defaults to the AWS ceiling of 128; lower it for services with tighter restrictions. Inherited via context. Keys longer than this raise an error."
  type        = number
  default     = null

  validation {
    condition     = var.max_tag_key_length == null || (var.max_tag_key_length >= 1 && var.max_tag_key_length <= 128)
    error_message = "The max_tag_key_length must be between 1 and 128 (the AWS ceiling)."
  }
}

variable "max_tag_value_length" {
  description = "Maximum tag value length in Unicode characters. Defaults to the AWS ceiling of 256; lower it for services with tighter restrictions. Inherited via context. Values longer than this are truncated to (limit - 5) characters plus a 5-char hash."
  type        = number
  default     = null

  validation {
    condition     = var.max_tag_value_length == null || (var.max_tag_value_length >= 6 && var.max_tag_value_length <= 256)
    error_message = "The max_tag_value_length must be between 6 and 256 (the AWS ceiling), leaving room for the 5-char truncation hash."
  }
}

variable "tags" {
  description = "Additional tags to merge on top of the generated ohi:* and Name tags. At most 50 user-created tags; keys must be 1-128 and values at most 256 Unicode characters (over-long values are truncated with a hash). Keys and values may only contain letters, numbers, spaces and _ . : / = + - @."
  type        = map(string)
  default     = {}
}
