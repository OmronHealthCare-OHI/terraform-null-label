# terraform-null-label

CloudPosse-null-label-style labeling for AWS resources that follows the OMRON
(Voltron) Cloud Tagging Convention. It turns a small set of semantic inputs
(country, stage, region, project/application/module, …) into a consistent
resource `id` and a set of `ohi:*` tags, and passes a `context` object down to
child modules so nested resources inherit the parent label and override only
what they need.

## Features

- **Deterministic id** — `<PREFIX>-<project>-<application>-<name>-<attributes...>`,
  where `PREFIX = <country><stage>-<deployment_region>` (e.g. `usstg-usw2`,
  or `usnp-usw2` when `non_prd = true`). The `project`/`application` hierarchy is
  composed in front of the leaf `name`, so `name` stays short; `module` is not
  part of the id (it lives in the `ohi:module` tag).
- **OMRON `ohi:*` tag hierarchy** — `ohi:project`, `ohi:application`,
  `ohi:module`, `ohi:stack-name`, `ohi:environment`, plus the AWS `Name` tag.
  `ohi:stack-name` is derived as `<PREFIX>-<deepest hierarchy>` (module, else
  application, else project), so all resources in a stack share it — it's the
  environment-specific instance of `ohi:module`. Empty segments are dropped; the
  tag-key prefix is configurable via `tag_prefix` (set `""` for unprefixed keys).
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
  stage             = "stg"
  deployment_region = "usw2"

  project     = "vlt"
  application = "mobile" # -> ohi:application = vlt-mobile
  module      = "be"     # -> ohi:module = vlt-mobile-be, ohi:stack-name = usstg-usw2-vlt-mobile-be

  tags = {
    Team = "voltron"
  }
}

# Child label: inherits the root context (project/application), sets only its
# short leaf name + attribute. The id composes the inherited hierarchy.
module "api_label" {
  source = "path/to/null-label"

  context    = module.label.context
  name       = "api" # -> id = usstg-usw2-vlt-mobile-api-v1
  attributes = ["v1"]
}
```

See [`examples/complete`](examples/complete) for more (non-prod resources,
unprefixed tag keys, and a length-limited id).

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |

### Providers

No providers.

### Modules

No modules.

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_application"></a> [application](#input\_application) | Application segment appended to project to form ohi:application (e.g. "mobile" -> vlt-mobile). Leave empty when the application equals the project (e.g. the infra set). | `string` | `null` | no |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | Ordered list of extra attributes appended to the id. Following CloudPosse null-label, attributes is an independent segment emitted whenever present — it can appear even without a name (e.g. <PREFIX>-<attr>). Merged onto any inherited from context. | `list(string)` | `null` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region code, e.g. us-west-2, eu-west-1, ap-northeast-1. When deployment\_region is not set, the PREFIX region segment is derived from this value. | `string` | `null` | no |
| <a name="input_context"></a> [context](#input\_context) | Inherited label context from a parent module invocation. Explicit variables override matching context fields; attributes and tags are merged. | <pre>object({<br/>    enabled              = optional(bool, true)<br/>    country              = optional(string, null)<br/>    stage                = optional(string, null)<br/>    aws_region           = optional(string, null)<br/>    deployment_region    = optional(string, null)<br/>    project              = optional(string, null)<br/>    application          = optional(string, null)<br/>    module               = optional(string, null)<br/>    stack_suffix         = optional(string, null)<br/>    owner                = optional(string, null)<br/>    name                 = optional(string, null)<br/>    attributes           = optional(list(string), [])<br/>    non_prd              = optional(bool, false)<br/>    delimiter            = optional(string, "-")<br/>    prefix_enabled       = optional(bool, true)<br/>    tag_prefix           = optional(string, "ohi")<br/>    tag_delimiter        = optional(string, ":")<br/>    id_length_limit      = optional(number, null)<br/>    max_tag_key_length   = optional(number, null)<br/>    max_tag_value_length = optional(number, null)<br/>    tags                 = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_country"></a> [country](#input\_country) | Country code, e.g. us, eu, jp, in, sg, br. | `string` | `null` | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter between id segments. | `string` | `null` | no |
| <a name="input_deployment_region"></a> [deployment\_region](#input\_deployment\_region) | Deployment region short code, e.g. usw2, euw1, apn1. Overwrites the AWS region code for the PREFIX segment. When null, it is derived from aws\_region. | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to produce an empty id and no tags. | `bool` | `null` | no |
| <a name="input_id_length_limit"></a> [id\_length\_limit](#input\_id\_length\_limit) | Limit the generated id output to at most this many characters. When the full id is longer, the leading characters are kept and a short md5 hash is appended so distinct ids stay unique (CloudPosse null-label parity). The Name tag is unaffected — it carries the full id, bound only by the tag-value limit. Set to 0 for unlimited length (default), or null to inherit from context. Minimum 6 when set; with very small limits or multi-character delimiters the leading portion and/or delimiter may be dropped (the id can be shorter than the limit), but the 5-char hash is always preserved. Does not affect the id segments carried in context. | `number` | `null` | no |
| <a name="input_max_tag_key_length"></a> [max\_tag\_key\_length](#input\_max\_tag\_key\_length) | Maximum tag key length in Unicode characters. Defaults to the AWS ceiling of 128; lower it for services with tighter restrictions. Inherited via context. Keys longer than this raise an error. | `number` | `null` | no |
| <a name="input_max_tag_value_length"></a> [max\_tag\_value\_length](#input\_max\_tag\_value\_length) | Maximum tag value length in Unicode characters. Defaults to the AWS ceiling of 256; lower it for services with tighter restrictions. Inherited via context. Values longer than this are truncated to (limit - 5) characters plus a 5-char hash. | `number` | `null` | no |
| <a name="input_module"></a> [module](#input\_module) | Module segment appended to form ohi:module (e.g. "be" -> vlt-mobile-be, "infra" -> vlt-infra). | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The leaf resource name. The id composes the inherited hierarchy in front of it — <PREFIX>-<project>-<application>-<name>-<attributes...> — so keep it short (e.g. project=vlt, application=mobile, name="api" -> usstg-usw2-vlt-mobile-api). The project/application segments come from those inputs, not from name. | `string` | `null` | no |
| <a name="input_non_prd"></a> [non\_prd](#input\_non\_prd) | When true, the stage segment becomes <country>np (e.g. usnp) so resources shared across the non-prod stages (dev/qa/stg) carry a single non-prod stage. | `bool` | `null` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | The circle that controls the resource. Emitted as the ohi:owner tag (subject to tag\_prefix/tag\_delimiter). Not part of the id or the ohi:* naming hierarchy. | `string` | `null` | no |
| <a name="input_prefix_enabled"></a> [prefix\_enabled](#input\_prefix\_enabled) | When true (default) the generated id is prefixed with the PREFIX. Set to false for resources that must not carry the prefix. | `bool` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Top of the tag hierarchy and the leading segment of every ohi:* value, e.g. vlt, common. | `string` | `null` | no |
| <a name="input_stack_suffix"></a> [stack\_suffix](#input\_stack\_suffix) | OPTIONAL override for ohi:stack-name. By default ohi:stack-name is derived as <PREFIX>-<deepest hierarchy> (module, else application, else project), so this is NOT needed for normal use. Set it only to pin an exact value <PREFIX>-<stack\_suffix> when something external depends on a specific stack name; it can be removed from the module if nobody uses it. | `string` | `null` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | Stage code, e.g. dev, qa, stg, prd. Ignored for the stage segment when non\_prd = true. | `string` | `null` | no |
| <a name="input_tag_delimiter"></a> [tag\_delimiter](#input\_tag\_delimiter) | Delimiter between tag key segments (e.g. ":" produces ohi:project). null inherits from context (defaults to ":"). The Name tag is never affected by this setting. | `string` | `null` | no |
| <a name="input_tag_prefix"></a> [tag\_prefix](#input\_tag\_prefix) | Prefix segment prepended to the generated tag keys, joined to the key by tag\_delimiter (e.g. "ohi" + ":" produces ohi:project). Set to "" for unprefixed keys (project, application, …). null inherits from context (defaults to "ohi"). The Name tag is never prefixed. Must not resolve to the reserved "aws:" prefix. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags to merge on top of the generated ohi:* and Name tags. At most 50 user-created tags; keys must be at most max\_tag\_key\_length (default 128) and values at most max\_tag\_value\_length (default 256) Unicode characters — both default to the AWS maxima but can be lowered for stricter services (over-long values are truncated with a hash). Keys and values may only contain letters, numbers, spaces and \_ . : / = + - @. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_context"></a> [context](#output\_context) | The label context to pass to child label modules. |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether this label is enabled. |
| <a name="output_id"></a> [id](#output\_id) | The generated id: the non-empty segments joined by the delimiter — <PREFIX>, <project>, <application>, <name>, then <attributes...>. module is not part of the id (it lives in the ohi:module tag). The prefix is omitted when prefix\_enabled = false. Truncated (with a trailing hash) when it exceeds id\_length\_limit. Empty when enabled = false. |
| <a name="output_id_full"></a> [id\_full](#output\_id\_full) | The untruncated id, before any id\_length\_limit is applied. Equals id when id\_length\_limit is 0 (unlimited) or the id already fits. |
| <a name="output_name"></a> [name](#output\_name) | The resolved name segment (the `name` input, inherited via context). Use `id` for the full generated identifier. |
| <a name="output_prefix"></a> [prefix](#output\_prefix) | The computed PREFIX: <country><stage>-<deployment\_region> (or <country>np-<region> when non\_prd). |
| <a name="output_tags"></a> [tags](#output\_tags) | The generated tags: the required ohi:* tags + Name, merged with any additional tags. Values are capped at max\_tag\_value\_length Unicode characters (default 256, the AWS ceiling). |
<!-- END_TF_DOCS -->
