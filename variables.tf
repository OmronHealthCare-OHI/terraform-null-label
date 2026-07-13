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
    enabled           = optional(bool, true)
    country           = optional(string, null)
    environment       = optional(string, null)
    deployment_region = optional(string, null)
    project           = optional(string, null)
    application       = optional(string, null)
    module            = optional(string, null)
    stackname         = optional(string, null)
    name              = optional(string, null)
    attributes        = optional(list(string), [])
    non_prd           = optional(bool, false)
    delimiter         = optional(string, "-")
    prefix_enabled    = optional(bool, true)
    tag_prefix        = optional(string, "ohi:")
    tags              = optional(map(string), {})
  })
  default = {}
}

variable "enabled" {
  description = "Set to false to produce an empty id and no tags."
  type        = bool
  default     = null
}

# --- PREFIX parts: <country><environment>-<deployment_region>, e.g. usstg-usw2 ---

variable "country" {
  description = "Country code, e.g. us, eu, jp, in, sg, br."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment code, e.g. dev, qa, stg, beta, prd. Ignored for the environment segment when non_prd = true."
  type        = string
  default     = null
}

variable "deployment_region" {
  description = "Deployment region short code, e.g. usw2, euw1, apne1."
  type        = string
  default     = null
}

variable "non_prd" {
  description = "When true, the environment segment becomes <country>np (e.g. usnp) so resources shared across the non-prod stages (dev/qa/stg/beta) carry a single non-prod environment."
  type        = bool
  default     = null
}

# --- Tag hierarchy (ohi:project / ohi:application / ohi:module / ohi:stack-name) ---

variable "project" {
  description = "ohi:project, e.g. vlt, common."
  type        = string
  default     = null
}

variable "application" {
  description = "ohi:application, e.g. vlt-mobile, vlt-monitoring, vlt-shared-services."
  type        = string
  default     = null
}

variable "module" {
  description = "ohi:module, e.g. vlt-mobile-be, vlt-users, vlt-infra."
  type        = string
  default     = null
}

variable "stackname" {
  description = "ohi:stack-name, e.g. usstg-usw2-vlt-be-serverless-stack."
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
  description = "Ordered list of extra attributes appended to the id after the name. Merged onto any inherited from context."
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
  description = "Prefix prepended to the generated tag keys, e.g. \"ohi:\" produces ohi:project. Set to \"\" for unprefixed keys (project, application, …). The Name tag is never prefixed."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to merge on top of the generated ohi:* and Name tags."
  type        = map(string)
  default     = {}
}
