# Related Projects

VDP is part of an ecosystem of specifications and implementations for server-driven UI rendering.

## HTMT — HyperText Markup Templating

[GitHub](https://github.com/ViewDescriptorProtocol/HTMT){ .md-button }

A templating engine using JSONPath-based `ht-*` data attributes for dynamic data binding in HTML/HTMX. HTMT extends standard HTML with custom attributes for declarative rendering and state management directly in the markup.

**Key attributes:**

| Attribute | Description |
|-----------|-------------|
| `ht-bind` | Bind data to element content |
| `ht-loop` | Iterate over arrays |
| `ht-template` | Reusable template blocks |
| `ht-attr-[name]` | Bind to HTML attributes |
| `ht-show` / `ht-hide` | Conditional visibility |
| `ht-switch` / `ht-case` | Switch-case rendering |
| `ht-class-[name]` | Conditional CSS classes |

All attributes use JSONPath expressions (e.g., `$.user.name`) for data binding.

HTMT templates can be used as VDP template targets — VDP declares *which* HTMT templates to render, while HTMT handles the actual data binding.

!!! note "Status"
    Working Draft (Alpha)

---

## js-HTF — JavaScript Hierarchical Template Framework

[GitHub](https://github.com/ViewDescriptorProtocol/js-HTF){ .md-button }

JavaScript implementation of the Hierarchical Template Framework. Provides a client-side runtime for resolving VDP view descriptors and rendering template trees in the browser.

!!! note "Status"
    Stub — implementation not yet started

---

## htmx-HTF — HTMX Integration for HTF

[GitHub](https://github.com/ViewDescriptorProtocol/htmx-HTF){ .md-button }

Integration layer between HTMX and the Hierarchical Template Framework. Enables HTMX-powered applications to leverage VDP view descriptors for server-driven partial page updates.

!!! note "Status"
    Stub — implementation not yet started

---

## GitHub Organization

All projects are hosted under the [ViewDescriptorProtocol](https://github.com/ViewDescriptorProtocol) GitHub organization.
