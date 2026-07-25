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

The **View Descriptor Protocol** defines a standard way for APIs to tell clients which templates to use for rendering a response. A view descriptor is a JSON structure that names a root template by URI and declares which sub-templates fill its named **slots**. Because each slot is itself described by a view descriptor, descriptors form a recursive template tree.

VDP works with **any rendering framework** — HTML/Qute, SwiftUI, Jetpack Compose, React, or anything else that supports named insertion points.

## Why VDP?

Without VDP, every client and BFF hardcodes its own copy of the same data-to-template mapping — change the presentation and you have to update each one. VDP moves that mapping to the API, declared once as a view descriptor:

![Diagram comparing the classical approach with VDP: on the left, the data-to-template view mapping is duplicated inside each client and BFF; on the right, a single view mapping lives on the API and travels to every client as a view descriptor](assets/diagrams/classical-vs-vdp-light.svg#only-light)
![Diagram comparing the classical approach with VDP: on the left, the data-to-template view mapping is duplicated inside each client and BFF; on the right, a single view mapping lives on the API and travels to every client as a view descriptor](assets/diagrams/classical-vs-vdp-dark.svg#only-dark)

<div class="vdp-features" markdown>

<div class="vdp-feature" markdown>

### Template Binding

Each API response carries a **view descriptor** — a compact JSON block that maps *which* template renders *which* data, using slots and template URIs. Templates handle the data binding themselves (Qute expressions, Mustache, Apache FreeMarker, JSONPath, etc.).

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

View descriptors are standalone resources with their own URLs, cacheable independently of the data they describe.

</div>

<div class="vdp-feature" markdown>

### Cross-Platform

One API response, multiple views. Serve different template trees — desktop, mobile, compact — from the same data endpoint.

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
  "template": "example.com/templates/layouts/sidebar",
  "slots": {
    "mainContent": {
      "template": "example.com/templates/dashboard",
      "slots": {
        "statsCards": {
          "template": "example.com/templates/components/card"
        },
        "activityTable": {
          "template": "example.com/templates/components/table"
        }
      }
    },
    "sidebarNav": {
      "template": "example.com/templates/components/nav"
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
