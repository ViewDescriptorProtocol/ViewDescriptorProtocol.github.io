---
hide:
  - navigation
  - toc
---

<div class="vdp-hero" markdown>

![VDP Logo](assets/logo.png)

# View Descriptor Protocol

<p class="vdp-tagline">Server-driven template binding for any client</p>

<div class="vdp-links" markdown>
[Read the Spec](specification.md){ .primary }
[View Examples](examples.md){ .secondary }
</div>

</div>

---

## What is VDP?

The **View Descriptor Protocol** defines a standard way for APIs to tell clients which templates to use for rendering data. A view descriptor is a JSON structure that identifies a root template by URL and declares how sub-templates compose into named **slots**, forming a recursive template tree.

VDP works with **any rendering framework** — HTML/Qute, SwiftUI, Jetpack Compose, React, or anything else that supports named insertion points.

<div class="vdp-features" markdown>

<div class="vdp-feature" markdown>

### Template Binding

The server declares *which* templates render *which* data. Templates handle data binding using their own mechanisms (Qute expressions, mustache, Apache FreeMarker, JSONPath, etc.).

</div>

<div class="vdp-feature" markdown>

### Recursive Slots

Templates compose via named slots. Each slot value is itself a view descriptor, enabling arbitrarily deep template trees — in other words, templates within templates.

</div>

<div class="vdp-feature" markdown>

### Dual Transport

Embed view descriptors inline (`_view` / `_views` in HAL+JSON) or reference them via HTTP `Link` headers ([RFC 8288](https://www.rfc-editor.org/rfc/rfc8288)) for constrained formats like OData4.

</div>

<div class="vdp-feature" markdown>

### Cacheable Descriptors

View descriptors are standalone resources with their own URLs, independently cacheable from the data they describe.

</div>

<div class="vdp-feature" markdown>

### Cross-Platform

One API response, multiple views. Serve different template trees for desktop, mobile, compact, and full layouts from the same data endpoint.

</div>

<div class="vdp-feature" markdown>

### Standards-Compatible

Built on REST, HAL, [RFC 8288](https://www.rfc-editor.org/rfc/rfc8288), and OData4. VDP extends existing standards without breaking them.

</div>

</div>

## Quick Example

A VDP view descriptor tells the client to render a sidebar layout, filling its slots with a dashboard, navigation, and data components:

```json
{
  "template": "https://example.com/templates/layouts/sidebar",
  "slots": {
    "mainContent": {
      "template": "https://example.com/templates/dashboard",
      "slots": {
        "statsCards": {
          "template": "https://example.com/templates/components/card"
        },
        "activityTable": {
          "template": "https://example.com/templates/components/table"
        }
      }
    },
    "sidebarNav": {
      "template": "https://example.com/templates/components/nav"
    }
  }
}
```

## Status

VDP is in **early working draft** stage (v0.1, alpha). The specification is being actively developed.

<div class="vdp-links" markdown>
[GitHub Organization](https://github.com/ViewDescriptorProtocol){ .secondary }
[JSON Schema](schema.md){ .secondary }
</div>

*[VDP]: View Descriptor Protocol
*[HAL]: Hypertext Application Language
