# Schema Reference

The VDP JSON Schema defines the structure of view descriptor documents. It uses [JSON Schema draft-07](https://json-schema.org/specification-links#draft-7) and validates both standalone view descriptors and multi-view descriptors.

**Current version:** `vdp.v0-1.schema.json`

## Full Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://vdp.dev/schemas/vdp.v0-1.schema.json",
  "title": "View Descriptor Protocol (VDP) v0.1",
  "description": "Schema for VDP view descriptor documents. Validates standalone ViewDescriptor and MultiViewDescriptor payloads. Definitions in $defs can be referenced by other schemas for inline body transport (_view / _views).",

  "oneOf": [
    { "$ref": "#/$defs/ViewDescriptor" },
    { "$ref": "#/$defs/MultiViewDescriptor" }
  ],

  "$defs": {
    "ViewDescriptor": {
      "type": "object",
      "description": "A view descriptor identifying a root template URL and its dynamic slot assignments. Slots are recursive — each slot value is itself a ViewDescriptor or an array of ViewDescriptors.",
      "properties": {
        "template": {
          "$ref": "#/$defs/TemplateURL"
        },
        "slots": {
          "$ref": "#/$defs/Slots"
        }
      },
      "required": ["template"],
      "additionalProperties": false
    },

    "TemplateURL": {
      "type": "string",
      "format": "uri",
      "description": "A URL identifying a template resource. MUST use HTTPS in production environments."
    },

    "Slots": {
      "type": "object",
      "description": "A map of slot names to slot values. Each key is a named insertion point in the parent template. Each value is a ViewDescriptor (single template) or an array of ViewDescriptors (multiple templates rendered in sequence).",
      "additionalProperties": {
        "$ref": "#/$defs/SlotValue"
      }
    },

    "SlotValue": {
      "description": "A single ViewDescriptor or an ordered array of ViewDescriptors. Arrays are rendered in sequence within the slot.",
      "oneOf": [
        { "$ref": "#/$defs/ViewDescriptor" },
        {
          "type": "array",
          "items": {
            "$ref": "#/$defs/ViewDescriptor"
          },
          "minItems": 1
        }
      ]
    },

    "MultiViewDescriptor": {
      "type": "object",
      "description": "Multiple named view descriptors for a single API response. Clients SHOULD use the 'default' view when no specific view is requested.",
      "properties": {
        "views": {
          "type": "object",
          "description": "A map of view names to ViewDescriptors.",
          "additionalProperties": {
            "$ref": "#/$defs/ViewDescriptor"
          },
          "minProperties": 1
        }
      },
      "required": ["views"],
      "additionalProperties": false
    },

    "DiscoveryDocument": {
      "type": "object",
      "description": "VDP discovery document served at /.well-known/vdp. Allows clients to prefetch view descriptors and identify trusted template domains.",
      "properties": {
        "version": {
          "type": "string",
          "description": "VDP specification version supported by this API."
        },
        "endpoints": {
          "type": "object",
          "description": "A map of API endpoint paths to their default view descriptors.",
          "additionalProperties": {
            "$ref": "#/$defs/ViewDescriptor"
          }
        },
        "trustedTemplateDomains": {
          "type": "array",
          "description": "Allowlist of base URLs from which templates may be loaded.",
          "items": {
            "type": "string",
            "format": "uri"
          }
        }
      },
      "required": ["version"]
    }
  }
}
```

## Type Reference

### ViewDescriptor

The core type. Identifies a root template and optionally declares slot assignments.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `template` | `TemplateURL` | Yes | URL identifying the template resource |
| `slots` | `Slots` | No | Map of slot names to slot values |

### TemplateURL

A URI string (`format: "uri"`) identifying a template resource. MUST use HTTPS in production.

### Slots

An object where each key is a slot name (matching an insertion point in the parent template) and each value is a `SlotValue`.

### SlotValue

One of:

- A single `ViewDescriptor` — one template fills the slot
- An array of `ViewDescriptor` objects — multiple templates rendered in sequence within the slot (minimum 1 item)

### MultiViewDescriptor

Wraps multiple named views for a single API response.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `views` | `object` | Yes | Map of view names to `ViewDescriptor` objects (minimum 1 entry) |

Clients SHOULD use the `default` view when no specific view is requested.

### DiscoveryDocument

Served at `/.well-known/vdp` for API discovery.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `version` | `string` | Yes | VDP specification version |
| `endpoints` | `object` | No | Map of API paths to their default view descriptors |
| `trustedTemplateDomains` | `string[]` | No | Allowlist of base URLs for template loading |

## Validation

The schema validates standalone VDP documents (view descriptor JSON files). For inline transport (`_view` / `_views` embedded in API responses), reference the `$defs` types from your own API schema:

```json
{
  "properties": {
    "_view": { "$ref": "https://vdp.dev/schemas/vdp.v0-1.schema.json#/$defs/ViewDescriptor" }
  }
}
```

To validate VDP examples locally:

```bash
cd VDP
podman run --rm -v .:/work:Z -w /work node:lts sh -c \
  "npm install --no-save ajv-cli ajv-formats && \
   npx ajv-cli test -s vdp.v0-1.schema.json -d 'examples/vdp-*.json' --valid -c ajv-formats"
```
