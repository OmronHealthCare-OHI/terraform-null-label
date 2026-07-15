# terraform-null-label

CloudPosse-null-label-style labeling for AWS resources that follows the OMRON
(Voltron) Cloud Tagging Convention. It turns a small set of semantic inputs
(country, environment, region, project/application/module, …) into a consistent
resource `id` and a set of `ohi:*` tags, and passes a `context` object down to
child modules so nested resources inherit the parent label and override only
what they need.

## Features

- **Deterministic id** — `<PREFIX>-<name>-<attributes...>`, where
  `PREFIX = <country><environment>-<deployment_region>` (e.g. `usstg-usw2`, or
  `usnp-usw2` when `non_prd = true`).
- **OMRON `ohi:*` tag hierarchy** — `ohi:project`, `ohi:application`,
  `ohi:module`, `ohi:stack-name`, `ohi:environment`, plus the AWS `Name` tag.
  Empty segments are dropped; the tag-key prefix is configurable via
  `tag_prefix` (set `""` for unprefixed keys).
- **Context inheritance** — every field is optional; a parent sets what it knows
  and passes `context` to children.
- **`id_length_limit`** — cap the `id` (for length-restricted resource
  identifiers). When the full id is longer, the leading characters are kept and
  a short `md5` hash is appended so distinct ids stay unique (CloudPosse
  parity). The `Name` tag keeps the full id, bound only by the tag-value limit.
- **AWS tag-constraint enforcement** — see below.

## AWS tag constraints

Enforced per the
[AWS Tag Editor reference](https://docs.aws.amazon.com/tag-editor/latest/userguide/reference.html):

| Constraint | Behaviour |
| --- | --- |
| At most 50 user-created tags (AWS-generated tags excluded) | error |
| Tag key length (default max 128, configurable via `max_tag_key_length`) | error |
| Tag key must not be empty | error |
| Tag key/value characters: letters, numbers, spaces and `_ . : / = + - @` | error |
| Tag key must not begin with the reserved `aws:` prefix | error |
| Tag value length (default max 256, configurable via `max_tag_value_length`) | truncated to `(limit - 5)` chars + a 5-char hash |

The length ceilings default to the AWS maxima but are configurable (and
inherited via `context`) because some services impose tighter limits.

## Usage

```hcl
# Root label for the vlt-mobile backend in us / stg.
module "label" {
  source = "path/to/null-label"

  country           = "us"
  environment       = "stg"
  deployment_region = "usw2"

  project      = "vlt"
  application  = "mobile"              # -> ohi:application = vlt-mobile
  module       = "be"                  # -> ohi:module      = vlt-mobile-be
  stack_suffix = "be-serverless-stack" # -> ohi:stack-name  = usstg-usw2-vlt-be-serverless-stack

  tags = {
    Team = "voltron"
  }
}

# Child label: inherits the root context, sets only its own name + attribute.
module "api_label" {
  source = "path/to/null-label"

  context    = module.label.context
  name       = "vlt-mobile-api" # -> id = usstg-usw2-vlt-mobile-api-v1
  attributes = ["v1"]
}
```

See [`examples/complete`](examples/complete) for more (non-prod resources,
unprefixed tag keys, and a length-limited id).

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |

### Providers

No providers.

### Modules

No modules.

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_application"></a> [application](#input\_application) | Application segment appended to project to form ohi:application (e.g. "mobile" -> vlt-mobile). Leave empty when the application equals the project (e.g. the infra set). | `string` | `null` | no |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | Ordered list of extra attributes appended to the id. Following CloudPosse null-label, attributes is an independent segment emitted whenever present — it can appear even without a name (e.g. <PREFIX>-<attr>). Merged onto any inherited from context. | `list(string)` | `null` | no |
| <a name="input_context"></a> [context](#input\_context) | Inherited label context from a parent module invocation. Explicit variables override matching context fields; attributes and tags are merged. | <pre>object({<br/>    enabled              = optional(bool, true)<br/>    country              = optional(string, null)<br/>    environment          = optional(string, null)<br/>    deployment_region    = optional(string, null)<br/>    project              = optional(string, null)<br/>    application          = optional(string, null)<br/>    module               = optional(string, null)<br/>    stack_suffix         = optional(string, null)<br/>    name                 = optional(string, null)<br/>    attributes           = optional(list(string), [])<br/>    non_prd              = optional(bool, false)<br/>    delimiter            = optional(string, "-")<br/>    prefix_enabled       = optional(bool, true)<br/>    tag_prefix           = optional(string, "ohi:")<br/>    id_length_limit      = optional(number, null)<br/>    max_tag_key_length   = optional(number, null)<br/>    max_tag_value_length = optional(number, null)<br/>    tags                 = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_country"></a> [country](#input\_country) | Country code, e.g. us, eu, jp, in, sg, br. | `string` | `null` | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter between id segments. | `string` | `null` | no |
| <a name="input_deployment_region"></a> [deployment\_region](#input\_deployment\_region) | Deployment region short code, e.g. usw2, euw1, apne1. | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to produce an empty id and no tags. | `bool` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment code, e.g. dev, qa, stg, beta, prd. Ignored for the environment segment when non\_prd = true. | `string` | `null` | no |
| <a name="input_id_length_limit"></a> [id\_length\_limit](#input\_id\_length\_limit) | Limit the generated id output to at most this many characters. When the full id is longer, the leading characters are kept and a short md5 hash is appended so distinct ids stay unique (CloudPosse null-label parity). The Name tag is unaffected — it carries the full id, bound only by the tag-value limit. Set to 0 for unlimited length (default), or null to inherit from context. Minimum 6 when set; with very small limits or multi-character delimiters the leading portion and/or delimiter may be dropped (the id can be shorter than the limit), but the 5-char hash is always preserved. Does not affect the id segments carried in context. | `number` | `null` | no |
| <a name="input_max_tag_key_length"></a> [max\_tag\_key\_length](#input\_max\_tag\_key\_length) | Maximum tag key length in Unicode characters. Defaults to the AWS ceiling of 128; lower it for services with tighter restrictions. Inherited via context. Keys longer than this raise an error. | `number` | `null` | no |
| <a name="input_max_tag_value_length"></a> [max\_tag\_value\_length](#input\_max\_tag\_value\_length) | Maximum tag value length in Unicode characters. Defaults to the AWS ceiling of 256; lower it for services with tighter restrictions. Inherited via context. Values longer than this are truncated to (limit - 5) characters plus a 5-char hash. | `number` | `null` | no |
| <a name="input_module"></a> [module](#input\_module) | Module segment appended to form ohi:module (e.g. "be" -> vlt-mobile-be, "infra" -> vlt-infra). | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The resource name appended after the PREFIX to form the id (e.g. vlt-mobile-api). | `string` | `null` | no |
| <a name="input_non_prd"></a> [non\_prd](#input\_non\_prd) | When true, the environment segment becomes <country>np (e.g. usnp) so resources shared across the non-prod stages (dev/qa/stg/beta) carry a single non-prod environment. | `bool` | `null` | no |
| <a name="input_prefix_enabled"></a> [prefix\_enabled](#input\_prefix\_enabled) | When true (default) the generated id is prefixed with the PREFIX. Set to false for resources that must not carry the prefix. | `bool` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Top of the tag hierarchy and the leading segment of every ohi:* value, e.g. vlt, common. | `string` | `null` | no |
| <a name="input_stack_suffix"></a> [stack\_suffix](#input\_stack\_suffix) | Suffix appended to <PREFIX>-<project> to form ohi:stack-name (e.g. "be-serverless-stack" -> usstg-usw2-vlt-be-serverless-stack). | `string` | `null` | no |
| <a name="input_tag_prefix"></a> [tag\_prefix](#input\_tag\_prefix) | Prefix prepended to the generated tag keys, e.g. "ohi:" produces ohi:project. Set to "" for unprefixed keys (project, application, …). The Name tag is never prefixed. Must not begin with the reserved "aws:" prefix. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to merge on top of the generated ohi:* and Name tags. At most 50 user-created tags; keys must be 1-128 and values at most 256 Unicode characters (over-long values are truncated with a hash). Keys and values may only contain letters, numbers, spaces and \_ . : / = + - @. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_context"></a> [context](#output\_context) | The label context to pass to child label modules. |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether this label is enabled. |
| <a name="output_id"></a> [id](#output\_id) | The generated id: the non-empty segments joined by the delimiter — <PREFIX>, <name>, then <attributes...>. The prefix is omitted when prefix\_enabled = false, and attributes may appear without a name (CloudPosse null-label parity). Truncated (with a trailing hash) when it exceeds id\_length\_limit. Empty when enabled = false. |
| <a name="output_id_full"></a> [id\_full](#output\_id\_full) | The untruncated id, before any id\_length\_limit is applied. Equals id when id\_length\_limit is 0 (unlimited) or the id already fits. |
| <a name="output_name"></a> [name](#output\_name) | The resolved name segment (the `name` input, inherited via context). Use `id` for the full generated identifier. |
| <a name="output_prefix"></a> [prefix](#output\_prefix) | The computed PREFIX: <country><environment>-<deployment\_region> (or <country>np-<region> when non\_prd). |
| <a name="output_tags"></a> [tags](#output\_tags) | The generated tags: the required ohi:* tags + Name, merged with any additional tags. Values are capped at 256 Unicode characters. |
<!-- END_TF_DOCS -->
