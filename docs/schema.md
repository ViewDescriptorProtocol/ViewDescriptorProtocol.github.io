# Schema Reference

The VDP JSON Schemas define the structure of view descriptor documents and the discovery document. Both use the [JSON Schema 2020-12](https://json-schema.org/specification-links#2020-12) dialect.

**Current versions**, published at their canonical `$id` URLs:

- [`vdp.v0-1.schema.json`](https://vdprotocol.org/schemas/vdp.v0-1.schema.json) — validates standalone view descriptors and multi-view descriptors
- [`vdp-discovery.v0-1.schema.json`](https://vdprotocol.org/schemas/vdp-discovery.v0-1.schema.json) — validates the discovery document served at `/.well-known/vdp`

Because the schemas are hosted at their `$id` URLs, they can be referenced directly from other schemas and validators.

## View Descriptor Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://vdprotocol.org/schemas/vdp.v0-1.schema.json",
  "title": "View Descriptor Protocol (VDP) v0.1",
  "description": "Schema for VDP view descriptor documents. Validates standalone ViewDescriptor and MultiViewDescriptor payloads. Definitions in $defs can be referenced by other schemas for inline body transport (_view / _views). The discovery document served at /.well-known/vdp has its own schema: vdp-discovery.v0-1.schema.json.",

  "oneOf": [
    { "$ref": "#/$defs/ViewDescriptor" },
    { "$ref": "#/$defs/MultiViewDescriptor" }
  ],

  "$defs": {
    "ViewDescriptor": {
      "type": "object",
      "description": "A view descriptor identifying a root template URL and its dynamic slot assignments. Slots are recursive — each slot value is a ViewDescriptor, a DescriptorReference, or an array of either.",
      "properties": {
        "template": {
          "$ref": "#/$defs/TemplateURL"
        },
        "type": {
          "type": "string",
          "minLength": 1,
          "description": "Advisory media type (RFC 6838) of the template resource, e.g. text/x-qute. The Content-Type of the fetched template is authoritative."
        },
        "integrity": {
          "type": "string",
          "minLength": 1,
          "description": "Integrity metadata for the template resource in W3C Subresource Integrity format, e.g. sha384-<base64 digest>. A mismatch is treated as a template fetch failure."
        },
        "slots": {
          "$ref": "#/$defs/Slots"
        }
      },
      "required": ["template"],
      "additionalProperties": false
    },

    "DescriptorReference": {
      "type": "object",
      "description": "A reference to a standalone view descriptor resource, valid only as a slot value. The client fetches the URL and uses the result as the slot's descriptor. The URL may be a relative reference, resolved against the same base as the containing descriptor's template URLs.",
      "properties": {
        "descriptor": {
          "type": "string",
          "format": "uri-reference",
          "minLength": 1,
          "description": "URL of the referenced view descriptor resource."
        }
      },
      "required": ["descriptor"],
      "additionalProperties": false
    },

    "TemplateURL": {
      "type": "string",
      "format": "uri",
      "description": "A URL identifying a template resource. MUST use HTTPS (loopback addresses excepted for local development)."
    },

    "Slots": {
      "type": "object",
      "description": "A map of slot names to slot values. Each key is a named insertion point in the parent template. Each value is a SlotDescriptor (an inline ViewDescriptor or a DescriptorReference) or an array of SlotDescriptors rendered in sequence.",
      "additionalProperties": {
        "$ref": "#/$defs/SlotValue"
      }
    },

    "SlotDescriptor": {
      "description": "An inline ViewDescriptor or a DescriptorReference pointing at a standalone view descriptor resource.",
      "oneOf": [
        { "$ref": "#/$defs/ViewDescriptor" },
        { "$ref": "#/$defs/DescriptorReference" }
      ]
    },

    "SlotValue": {
      "description": "A single SlotDescriptor or an ordered array of SlotDescriptors. Arrays are rendered in sequence within the slot.",
      "oneOf": [
        { "$ref": "#/$defs/SlotDescriptor" },
        {
          "type": "array",
          "items": {
            "$ref": "#/$defs/SlotDescriptor"
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
    }
  }
}
```

## Discovery Document Schema

The discovery document is not a view descriptor — it is served as `application/vdp-discovery+json` (never `application/vdp+json`) and has its own schema:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://vdprotocol.org/schemas/vdp-discovery.v0-1.schema.json",
  "title": "View Descriptor Protocol (VDP) v0.1 Discovery Document",
  "description": "Schema for the VDP discovery document served at /.well-known/vdp as application/vdp-discovery+json (spec Section 13.2). Unrecognized members are permitted everywhere per the discovery extensibility clause: clients MUST ignore members they do not recognize.",

  "type": "object",
  "properties": {
    "version": {
      "type": "string",
      "description": "The VDP protocol version supported by the API (e.g. \"0.1\"). Matches the value advertised by the VDP-Version header.",
      "minLength": 1
    },
    "endpoints": {
      "type": "object",
      "description": "Maps API paths to their view descriptor resources. Keys are absolute paths relative to the origin serving the discovery document, and MAY be RFC 6570 Level 1 URI Templates (e.g. /api/products/{id}).",
      "propertyNames": {
        "pattern": "^/"
      },
      "additionalProperties": {
        "$ref": "#/$defs/EndpointEntry"
      }
    },
    "trustedTemplateUrls": {
      "type": "array",
      "description": "Template URL allowlist (spec Section 10). Each entry is a URL prefix; entries SHOULD end with a trailing slash.",
      "items": {
        "type": "string",
        "format": "uri",
        "minLength": 1
      }
    }
  },
  "required": ["version"],

  "$defs": {
    "EndpointEntry": {
      "type": "object",
      "description": "Discovery metadata for one API endpoint. Additional members are permitted for extensibility.",
      "properties": {
        "descriptor": {
          "type": "string",
          "format": "uri-reference",
          "description": "URL of the endpoint's view descriptor resource. MAY be a relative reference, resolved against the discovery document URL per RFC 3986.",
          "minLength": 1
        }
      },
      "required": ["descriptor"]
    }
  }
}
```

## Type Reference

### ViewDescriptor

The core type. Identifies a root template and optionally declares slot assignments and advisory template metadata.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `template` | `TemplateURL` | Yes | URL identifying the template resource |
| `type` | `string` | No | Advisory media type (RFC 6838) of the template resource; the fetched template's `Content-Type` is authoritative |
| `integrity` | `string` | No | W3C Subresource Integrity metadata for the template resource; a mismatch is treated as a template fetch failure |
| `slots` | `Slots` | No | Map of slot names to slot values |

### TemplateURL

A URI string (`format: "uri"`) identifying a template resource. MUST use HTTPS in production.

### Slots

An object where each key is a slot name (matching an insertion point in the parent template) and each value is a `SlotValue`.

### SlotValue

One of:

- A single `SlotDescriptor` — one template (or referenced descriptor) fills the slot
- An array of `SlotDescriptor` objects — multiple entries rendered in sequence within the slot (minimum 1 item)

### SlotDescriptor

Either an inline `ViewDescriptor` or a `DescriptorReference`.

### DescriptorReference

A reference to a standalone view descriptor resource, valid only as a slot value (never at the root). The client fetches the URL and uses the result as the slot's descriptor.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `descriptor` | `string` (uri-reference) | Yes | URL of the referenced view descriptor resource; may be relative, resolved against the same base as the containing descriptor's template URLs |

### MultiViewDescriptor

Wraps multiple named views for a single API response.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `views` | `object` | Yes | Map of view names to `ViewDescriptor` objects (minimum 1 entry) |

Clients SHOULD use the `default` view when no specific view is requested.

### Discovery Document

Served at `/.well-known/vdp` as `application/vdp-discovery+json` (Specification Sections 12.3 and 13.2). Unrecognized members anywhere in the document MUST be ignored by clients.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `version` | `string` | Yes | VDP protocol version supported by the API |
| `endpoints` | `object` | No | Map of API paths to `{ "descriptor": <url> }` entries. Keys are absolute paths relative to the origin serving the discovery document and MAY be RFC 6570 Level 1 URI Templates (e.g. `/api/products/{id}`). `descriptor` values MAY be relative references, resolved against the discovery document URL |
| `trustedTemplateUrls` | `string[]` | No | Template URL allowlist — trusted URL prefixes; entries SHOULD end with a trailing slash |

## Validation

The view descriptor schema validates standalone VDP documents (view descriptor JSON files). For inline transport (`_view` / `_views` embedded in API responses), reference the `$defs` types from your own API schema:

```json
{
  "properties": {
    "_view": { "$ref": "https://vdprotocol.org/schemas/vdp.v0-1.schema.json#/$defs/ViewDescriptor" }
  }
}
```

To validate the VDP examples locally:

```bash
cd VDP
podman run --rm -v .:/work:Z -w /work node:lts sh -c \
  "npm install --no-save ajv-cli ajv-formats && \
   npx ajv-cli test --spec=draft2020 -s vdp.v0-1.schema.json -d 'examples/vdp-*.json' --valid -c ajv-formats && \
   npx ajv-cli test --spec=draft2020 -s vdp-discovery.v0-1.schema.json -d 'examples/discovery-*.json' --valid -c ajv-formats"
```
