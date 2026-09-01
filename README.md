# terraform-null-label

OMRON (Voltron) Cloud Tagging Convention labeling for AWS resources. It **wraps
[`cloudposse/label/null`](https://registry.terraform.io/modules/cloudposse/label/null/) `0.25.0`**
— the version Luscii vendors — to generate the resource `id`/`Name` and the
standard `Namespace`/`Environment`/`Stage`/`Name` tags, and layers the OMRON
`ohi:*` tags on top. A small set of semantic inputs (namespace, region, stage,
application/module, …) becomes a consistent `id` and tag set, and a `context`
object passes down to child modules so nested resources inherit the parent label
and override only what they need.

**Why the wrap:** the AWS org splits accounts on non-prod/prod × region, so
`Stage` (dev/qa/stg/prd) is implied by the account rather than carried on the
resource — which makes tag-based ownership/coverage reporting blind to stage.
Delegating to CloudPosse gives every resource a **first-class, queryable `Stage`
tag** (and `Environment` = logical region).

## Features

- **Deterministic id (CloudPosse)** —
  `<namespace>-<region>-<stage>-<name>-<attributes...>`, e.g. `cnct-uk-prd-mobile-api`.
  `name` composes the `<application>-<leaf name>` hierarchy, so the leaf stays
  short; `module` is **not** part of the id (it lives in the `ohi:module` tag).
- **`stage` is a scope, not a flag** — one of `dev`, `qa`, `stg`, `prd`, or `np`
  for the whole non-prod set. `np` is **not** a deployment stage: use it only
  where the resource's scope genuinely is all of `dev`/`qa`/`stg` — the shared
  non-prod AWS account, which pairs with its prd partner as `cnct-us-np` /
  `cnct-us-prd`. A resource that is not stage-specific at all leaves `stage`
  unset: no stage segment in the id, and the `Stage` tag is dropped rather than
  emitted empty.
- **`namespace` is the product** — `cnct` (Connect/voltron), `crt` (Create), … —
  emitted as CloudPosse's `Namespace` tag and the leading id segment. **Required**
  (set the variable or inherit it via `context`).
- **Logical `region`** — the geo identifier (`us`, `eu`, `uk`, extensible), each
  linked to an AWS region (`us→us-east-1`, `eu→eu-central-1`, `uk→eu-west-2`).
  Emitted as CloudPosse's `Environment` tag. The **AWS region is a separate input
  (`aws_region`)** emitted as the `ohi:aws-region` tag — it is **not** part of the
  id (through account navigation the AWS region is already a given).
- **OMRON `ohi:*` tags** — `ohi:application`, `ohi:module`, `ohi:stack-name`,
  `ohi:owner`, `ohi:aws-region`. `ohi:module` nests as `<application>-<module>`;
  `ohi:stack-name` is `<namespace>-<region>-<stage>-<deepest hierarchy>` (module,
  else application), so all resources in a stack share it. The tag-key prefix is
  configurable via `tag_prefix` (set `""` for unprefixed keys); CloudPosse's
  `Namespace`/`Environment`/`Stage`/`Name` tags are unaffected by it.
- **Context inheritance** — every field is optional; a parent sets what it knows
  and passes `context` to children.
- **`id_length_limit`** — forwarded to CloudPosse: cap the `id` for
  length-restricted identifiers; when the full id is longer the leading
  characters are kept and a short hash is appended so distinct ids stay unique.
  The `Name` tag equals the (truncated) `id`.
- **AWS tag-constraint enforcement** — applied to the **merged** CloudPosse +
  `ohi:*` + user tag set, so a CloudPosse-emitted tag can't bypass the checks.
  See below.

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
# Root label for the mobile backend in the cnct (Connect) namespace, uk / prd.
module "label" {
  source = "path/to/null-label"

  namespace  = "cnct"      # product token -> id/Namespace
  region     = "uk"        # logical region -> Environment (uk = eu-west-2)
  stage      = "prd"       # -> Stage tag
  aws_region = "eu-west-2" # -> ohi:aws-region tag (NOT in the id)

  application = "mobile" # -> ohi:application = mobile
  module      = "be"     # -> ohi:module = mobile-be, ohi:stack-name = cnct-uk-prd-mobile-be

  tags = {
    Team = "voltron"
  }
}

# Child label: inherits the root context (namespace/region/stage/application),
# sets only its short leaf name + attribute. The id composes the hierarchy.
module "api_label" {
  source = "path/to/null-label"

  context    = module.label.context
  name       = "api" # -> id = cnct-uk-prd-mobile-api-v1
  attributes = ["v1"]
}
```

See [`examples/complete`](examples/complete) for more (a non-prod-wide `np`
resource, a stage-less resource, unprefixed tag keys, and a length-limited id).

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |

### Providers

No providers.

### Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cloudposse_label"></a> [cloudposse\_label](#module\_cloudposse\_label) | cloudposse/label/null | 0.25.0 |

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_application"></a> [application](#input\_application) | Application segment under the namespace, e.g. "mobile" -> ohi:application = mobile, and the leading part of the id name (cnct-uk-prd-mobile-...). Leave empty for namespace-level (e.g. shared infra). | `string` | `null` | no |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | Ordered list of extra attributes appended to the id. Merged onto any inherited from context. | `list(string)` | `null` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region code, e.g. us-east-1, eu-central-1, eu-west-2. Emitted as the ohi:aws-region tag; NOT part of the id (through account navigation the AWS region is already a given). | `string` | `null` | no |
| <a name="input_context"></a> [context](#input\_context) | Inherited label context from a parent module invocation. Explicit variables override matching context fields; attributes and tags are merged. | <pre>object({<br/>    enabled              = optional(bool, true)<br/>    namespace            = optional(string, null)<br/>    region               = optional(string, null)<br/>    stage                = optional(string, null)<br/>    aws_region           = optional(string, null)<br/>    application          = optional(string, null)<br/>    module               = optional(string, null)<br/>    stack_suffix         = optional(string, null)<br/>    stack_name_enabled   = optional(bool, true)<br/>    owner                = optional(string, null)<br/>    name                 = optional(string, null)<br/>    attributes           = optional(list(string), [])<br/>    delimiter            = optional(string, "-")<br/>    tag_prefix           = optional(string, "ohi")<br/>    tag_delimiter        = optional(string, ":")<br/>    id_length_limit      = optional(number, null)<br/>    max_tag_key_length   = optional(number, null)<br/>    max_tag_value_length = optional(number, null)<br/>    tags                 = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter between id and tag-hierarchy segments. null inherits from context (defaults to "-"). | `string` | `null` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to produce an empty id and no tags. | `bool` | `null` | no |
| <a name="input_id_length_limit"></a> [id\_length\_limit](#input\_id\_length\_limit) | Limit the generated id to at most this many characters (forwarded to CloudPosse null-label). When the full id is longer, the leading characters are kept and a short hash is appended so distinct ids stay unique. Set to 0 for unlimited length (default), or null to inherit from context. Minimum 6 when set. | `number` | `null` | no |
| <a name="input_max_tag_key_length"></a> [max\_tag\_key\_length](#input\_max\_tag\_key\_length) | Maximum tag key length in Unicode characters. Defaults to the AWS ceiling of 128; lower it for services with tighter restrictions. Inherited via context. Keys longer than this raise an error. | `number` | `null` | no |
| <a name="input_max_tag_value_length"></a> [max\_tag\_value\_length](#input\_max\_tag\_value\_length) | Maximum tag value length in Unicode characters. Defaults to the AWS ceiling of 256; lower it for services with tighter restrictions. Inherited via context. Values longer than this are truncated to (limit - 5) characters plus a 5-char hash. | `number` | `null` | no |
| <a name="input_module"></a> [module](#input\_module) | Module segment appended to application to form ohi:module (e.g. "be" under application "mobile" -> mobile-be). Not part of the id. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The leaf resource name. The id composes <namespace>-<region>-<stage>-<application>-<name>, so keep it short (e.g. namespace=cnct, application=mobile, name="api" -> cnct-uk-prd-mobile-api). | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Product namespace and leading id segment, e.g. cnct (Connect), crt (Create), luscii. REQUIRED: must resolve from this variable or the inherited context when enabled. | `string` | `null` | no |
| <a name="input_owner"></a> [owner](#input\_owner) | The circle that controls the resource. Emitted as the ohi:owner tag (subject to tag\_prefix/tag\_delimiter). Not part of the id. | `string` | `null` | no |
| <a name="input_owner_propagation_enabled"></a> [owner\_propagation\_enabled](#input\_owner\_propagation\_enabled) | When true (default) owner is carried into the exported context, so child labels inherit it. Set to false to withhold owner from the context: this label still emits its own ohi:owner tag, but child labels start without an owner and must state their own explicitly. This is a ONE-LEVEL ownership reset: the toggle itself is NOT part of the context and does not travel. null means the default (true). | `bool` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | Logical region code (the geo identifier in the id), e.g. us, eu, uk. Each logical region maps to an AWS region (us->us-east-1, eu->eu-central-1, uk->eu-west-2) and is extensible. This is NOT the AWS region code — set aws\_region for that. | `string` | `null` | no |
| <a name="input_stack_name_enabled"></a> [stack\_name\_enabled](#input\_stack\_name\_enabled) | When true (default) the ohi:stack-name tag is emitted. Set to false to drop the tag for labels where a stack name is not meaningful. Inherited by child labels via context; null inherits from context. | `bool` | `null` | no |
| <a name="input_stack_suffix"></a> [stack\_suffix](#input\_stack\_suffix) | OPTIONAL override for ohi:stack-name. By default ohi:stack-name is <namespace>-<region>-<stage>-<deepest hierarchy> (module, else application). Set it only to pin an exact leaf when something external depends on a specific stack name. | `string` | `null` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | Stage scope of the resource: a single deployment stage (dev, qa, stg, prd) or "np" for the whole non-prod set. "np" is NOT a deployment stage — use it only where the resource's scope genuinely is all of dev/qa/stg, e.g. the shared non-prod AWS account, which pairs with the prd account as cnct-us-np / cnct-us-prd. A resource that is not stage-specific at all should leave stage unset (no Stage tag, no stage segment). | `string` | `null` | no |
| <a name="input_tag_delimiter"></a> [tag\_delimiter](#input\_tag\_delimiter) | Delimiter between tag key segments (e.g. ":" produces ohi:application). null inherits from context (defaults to ":"). | `string` | `null` | no |
| <a name="input_tag_prefix"></a> [tag\_prefix](#input\_tag\_prefix) | Prefix segment prepended to the generated OMRON tag keys, joined to the key by tag\_delimiter (e.g. "ohi" + ":" produces ohi:application). Set to "" for unprefixed keys. null inherits from context (defaults to "ohi"). CloudPosse's Namespace/Environment/Stage/Name tags are unaffected. Must not resolve to the reserved "aws:" prefix. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags merged with the generated CloudPosse + ohi:* tags. On a key collision the GENERATED tags win, so the standard keys (Namespace, Environment, Stage, Name, ohi:*) cannot be overridden or cleared. AWS counts the generated tags toward its 50-tag cap, so the final emitted map (generated + additional) may hold at most 50 entries. Keys at most max\_tag\_key\_length (default 128) and values at most max\_tag\_value\_length (default 256) Unicode characters. Keys and values may only contain letters, numbers, spaces and \_ . : / = + - @. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_context"></a> [context](#output\_context) | The label context to pass to child label modules. |
| <a name="output_enabled"></a> [enabled](#output\_enabled) | Whether this label is enabled. |
| <a name="output_id"></a> [id](#output\_id) | The generated id from CloudPosse null-label: <namespace>-<region>-<stage>-<name>-<attributes...> (module is not part of the id — it lives in the ohi:module tag). Truncated (with a trailing hash) when it exceeds id\_length\_limit. Empty when enabled = false. |
| <a name="output_id_full"></a> [id\_full](#output\_id\_full) | The untruncated id, before any id\_length\_limit is applied. Equals id when id\_length\_limit is 0 (unlimited) or the id already fits. |
| <a name="output_name"></a> [name](#output\_name) | The normalized name component (the composed <application>-<name> leaf). Use `id` for the full generated identifier. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | The resolved namespace (product token). |
| <a name="output_region"></a> [region](#output\_region) | The resolved logical region (CloudPosse environment segment). |
| <a name="output_stage"></a> [stage](#output\_stage) | The resolved stage scope: a single stage (dev/qa/stg/prd), "np" for the whole non-prod set, or empty when the resource is not stage-specific. |
| <a name="output_tags"></a> [tags](#output\_tags) | The generated tags: CloudPosse's Namespace/Environment/Stage/Name + the OMRON ohi:* tags (ohi:application, ohi:module, ohi:stack-name, ohi:owner, ohi:aws-region), merged with any additional tags. Values are capped at max\_tag\_value\_length Unicode characters (default 256, the AWS ceiling). |
<!-- END_TF_DOCS -->
