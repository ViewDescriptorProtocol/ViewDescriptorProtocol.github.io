# View Descriptor Protocol (VDP)

**Status:** Working Draft
**Version:** 0.1.0

## Abstract

The View Descriptor Protocol (VDP) defines a standard mechanism for associating API data responses with the templates that should render them. A **view descriptor** is a JSON structure that identifies a root template by URL and declares how sub-templates compose into named slots, forming a recursive template tree. View descriptors can be transported via HTTP headers (for constrained formats like OData4) or inline in the response body (for flexible formats like HAL+JSON). The protocol is framework-agnostic — templates can be HTML/Qute, SwiftUI views, Compose layouts, or any other rendering format.

## 1. Problem Statement

REST APIs return structured data (JSON, XML) that carries no presentation information. The client must independently decide how to render this data — typically by hardcoding template choices into client logic. This creates tight coupling between API consumers and their rendering layer.

**VDP solves this by letting the server declare:**
- Which template(s) to use for rendering a response
- How templates compose together (which sub-template fills which slot)

**VDP explicitly does NOT define:**
- How templates bind to data (that is the template engine's job — Qute expressions, JSONPath, etc.)
- Styling or CSS class information (that belongs in the template itself)
- Client-side state management

## 2. Terminology

- **View Descriptor**: A JSON object that describes a template tree — a root template URL and its slot assignments.
- **Template URL**: A URL identifying a template resource. The URL MUST resolve to a renderable template in the client's rendering framework.
- **Slot**: A named insertion point in a template where a sub-template can be composed. Slot names correspond to the template's own insertion point identifiers (e.g., Qute's `{#insert slotName}`, HTML's `<slot name="slotName">`).
- **View Descriptor Resource**: A standalone JSON document containing a view descriptor, addressable by its own URL, cacheable independently of the data it describes.
- **Static Composition**: Template includes that are hardcoded within the template itself (e.g., a layout always including its `_head.html` partial). VDP does not manage these — they are the template's internal concern.
- **Dynamic Composition**: Template slots whose content varies per API response. VDP manages these.

## 3. View Descriptor Format

### 3.1 Basic Structure (Single Template)

The simplest view descriptor points to a single template with no slots:

```json
{
  "template": "https://example.com/templates/article.html"
}
```

### 3.2 Template Composition (Slots)

When a template has named insertion points that should be filled dynamically, the view descriptor declares a `slots` object. Each key is a slot name matching an insertion point in the template, and each value is itself a view descriptor:

```json
{
  "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/layouts/sidebar.html",
  "slots": {
    "mainContent": {
      "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card.html"
    },
    "sidebarNav": {
      "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/navigation/nav.html"
    }
  }
}
```

This tells the client: "Render `sidebar.html`, and fill its `mainContent` slot with `card.html` and its `sidebarNav` slot with `nav.html`."

### 3.3 Recursive Nesting

Since each slot value is itself a view descriptor, composition nests to arbitrary depth:

```json
{
  "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/layouts/sidebar.html",
  "slots": {
    "mainContent": {
      "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/demos/dashboard.html",
      "slots": {
        "statsRow": {
          "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card.html"
        },
        "activityTable": {
          "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/table.html"
        },
        "chart": {
          "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/charts/chart.html",
          "slots": {
            "legend": {
              "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/charts/chart-legend.html"
            }
          }
        }
      }
    },
    "sidebarNav": {
      "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/navigation/nav.html"
    }
  }
}
```

### 3.4 Multiple Views

A single API response may offer multiple views (e.g., a summary view and a detail view, or views for different device classes). Use a named object at the top level:

```json
{
  "views": {
    "default": {
      "template": "https://example.com/templates/product-detail.html"
    },
    "compact": {
      "template": "https://example.com/templates/product-card.html"
    },
    "mobile": {
      "template": "https://example.com/templates/product-mobile.html",
      "slots": {
        "gallery": {
          "template": "https://example.com/templates/components/swipe-gallery.html"
        }
      }
    }
  }
}
```

When only a single view is needed, the top-level object IS the view descriptor (no `views` wrapper). When multiple views are present, the `views` key wraps them. A client SHOULD use `default` when no specific view is requested.

### 3.5 Slot Arrays

A single slot can accept multiple templates, rendered in sequence within the insertion point. This is useful when composing multiple independent components into a single region:

```json
{
  "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/layouts/sidebar.html",
  "slots": {
    "mainContent": [
      {
        "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card.html"
      },
      {
        "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/charts/chart.html"
      },
      {
        "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/table.html"
      }
    ],
    "sidebarNav": {
      "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/navigation/nav.html"
    }
  }
}
```

Each element in the array is a full view descriptor and can itself have nested `slots`. The client MUST render array elements in order.

### 3.6 Formal Grammar

```
ViewDescriptor      = { "template": TemplateURL, "slots"?: Slots }
TemplateURL         = URI (RFC 3986)
Slots               = { SlotName: SlotValue, ... }
SlotName            = string (matches an insertion point in the template)
SlotValue           = ViewDescriptor | ViewDescriptor[]

MultiViewDescriptor = { "views": { ViewName: ViewDescriptor, ... } }
ViewName            = string
```

A valid VDP payload is either a `ViewDescriptor` or a `MultiViewDescriptor`.

## 4. Transport Mechanisms

VDP supports two transport modes. Servers MAY use either or both.

### 4.1 HTTP Link Header (Standalone Resource)

The server responds with a `Link` header pointing to a view descriptor resource:

```http
HTTP/1.1 200 OK
Content-Type: application/json
Link: <https://example.com/views/dashboard.json>; rel="view-descriptor"

{"revenue": 48200, "users": 1847, "orders": 312}
```

The client fetches `https://example.com/views/dashboard.json` to get the view descriptor. This approach:

- Keeps the data payload completely clean
- Works with **any** data format (JSON, XML, OData4, GraphQL, Protocol Buffers)
- The view descriptor resource is independently cacheable
- Uses existing web standards (RFC 8288 Link Relations)

**For simple cases** (single template, no composition), a shorthand header is also defined:

```http
View-Template: https://example.com/templates/article.html
```

When `View-Template` is present, it is equivalent to `{"template": "<URL>"}`. If both `Link` (with `rel="view-descriptor"`) and `View-Template` are present, the `Link` header takes precedence.

### 4.2 Inline in Response Body

When the data format is flexible (e.g., HAL+JSON, custom APIs), embed the view descriptor directly using the `_view` key:

```json
{
  "_links": {
    "self": { "href": "/api/dashboard" }
  },
  "_view": {
    "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/demos/dashboard.html",
    "slots": {
      "statsRow": {
        "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card.html"
      }
    }
  },
  "revenue": 48200,
  "users": 1847,
  "orders": 312
}
```

The `_view` key follows HAL's underscore convention for protocol-level metadata.

For **multiple views**, use `_views`:

```json
{
  "_views": {
    "default": {
      "template": "https://example.com/templates/dashboard-full.html",
      "slots": { "..." : "..." }
    },
    "widget": {
      "template": "https://example.com/templates/dashboard-widget.html"
    }
  },
  "revenue": 48200,
  "users": 1847
}
```

### 4.3 OData4 Compatibility

OData4 responses have a rigid structure but support custom instance annotations. Use an annotation to reference a view descriptor resource:

```json
{
  "@odata.context": "https://example.com/odata/$metadata#Products",
  "@View.descriptor": "https://example.com/views/product-list.json",
  "value": [
    { "ProductID": 1, "Name": "Widget", "Price": 9.99 },
    { "ProductID": 2, "Name": "Gadget", "Price": 24.99 }
  ]
}
```

Alternatively, use the `Link` header approach (Section 4.1) to avoid touching the OData body entirely.

### 4.4 Precedence

When a view descriptor is provided via multiple mechanisms, precedence is:

1. Inline body (`_view` / `_views`) — most specific
2. `Link` header with `rel="view-descriptor"`
3. `View-Template` header

## 5. View Descriptor Resources

### 5.1 Media Type

View descriptor resources SHOULD be served with:

```
Content-Type: application/vdp+json
```

### 5.2 Caching

View descriptor resources are independently cacheable. Servers SHOULD provide standard HTTP caching headers:

```http
HTTP/1.1 200 OK
Content-Type: application/vdp+json
Cache-Control: public, max-age=3600
ETag: "v2-dashboard"

{
  "template": "https://example.com/templates/dashboard.html",
  "slots": { "..." : "..." }
}
```

Template URLs themselves are also cacheable resources. Clients SHOULD cache resolved templates according to their HTTP caching headers.

### 5.3 Versioning

View descriptors can be versioned by URL convention:

```
https://example.com/views/v2/dashboard.json
https://example.com/views/dashboard.json?v=2
```

Or by content negotiation using the `Accept` header with a version parameter:

```
Accept: application/vdp+json; version=2
```

### 5.4 URL Resolution

Template URLs in a view descriptor MAY be relative references (RFC 3986 Section 4.2). Clients MUST resolve relative URLs using the following base URL, in order of precedence:

1. **Standalone view descriptor resource**: The URL of the view descriptor resource itself (i.e., the URL used to fetch it via the `Link` header).
2. **Inline transport** (`_view` / `_views`): The URL of the API response containing the view descriptor.

Nested slot template URLs resolve against the same base URL as the root template URL — the base does not change at each nesting level.

**Example:**

Given an API response at `https://example.com/api/dashboard` with an inline view descriptor:

```json
{
  "_view": {
    "template": "templates/layouts/sidebar.html",
    "slots": {
      "mainContent": {
        "template": "templates/components/card.html"
      }
    }
  }
}
```

Both template URLs resolve against `https://example.com/api/dashboard`:
- `templates/layouts/sidebar.html` → `https://example.com/templates/layouts/sidebar.html`
- `templates/components/card.html` → `https://example.com/templates/components/card.html`

Servers SHOULD use absolute URLs when view descriptors may be consumed by multiple clients with different base URL contexts.

### 5.5 Client-Specific Selection

When different clients require different templates (e.g., HTML for web, Compose for Android, SwiftUI for iOS), the server SHOULD use standard HTTP content negotiation to select the appropriate view descriptor. VDP does not define a mechanism for shipping multiple platform variants in a single response — the server selects and returns one view descriptor per request.

Servers MAY use the `Accept` header, custom headers, or query parameters to determine the client's rendering platform:

```http
GET /api/dashboard HTTP/1.1
Accept: application/vdp+json
X-VDP-Platform: android
```

This keeps view descriptors small and avoids pushing selection logic into clients.

## 6. Template Requirements

VDP is agnostic to the template language. However, templates used with VDP MUST satisfy one requirement: **named insertion points (slots) that can be filled externally**.

### 6.1 Framework Slot Mappings

| Framework | Slot Mechanism | Example |
|-----------|---------------|---------|
| Qute | `{#insert slotName}{/insert}` | `{#insert mainContent}Default{/insert}` |
| HTML `<template>` | `<slot name="slotName">` | `<slot name="mainContent"></slot>` |
| HTMT | `ht-template="slotName"` | `<div ht-template="mainContent"></div>` |
| Thymeleaf | `th:fragment` / `th:replace` | `<div th:replace="~{slotName}"></div>` |
| JSX/React | `props.children` or named props | `{props.mainContent}` |
| SwiftUI | `@ViewBuilder` parameters | `var mainContent: () -> Content` |
| Jetpack Compose | `@Composable` slot parameters | `mainContent: @Composable () -> Unit` |

### 6.2 Static vs Dynamic Slots

Not all insertion points in a template need to be managed by VDP. Templates commonly include static partials (like a shared `_head.html` or a footer) that are hardcoded. Only slots that vary per API response need to appear in the view descriptor.

## 7. Examples

### 7.1 Login Page (Simple, No Slots)

**API Response:**

```http
HTTP/1.1 200 OK
Content-Type: application/json
View-Template: https://github.com/SiteNetSoft/quarkus-pha/templates/components/forms/form.html

{
  "csrfToken": "abc123",
  "loginUrl": "/auth/login",
  "fields": [
    { "name": "username", "type": "text", "label": "Username", "required": true },
    { "name": "password", "type": "password", "label": "Password", "required": true }
  ]
}
```

### 7.2 Dashboard (Composed Template Tree)

**API Response:**

```http
HTTP/1.1 200 OK
Content-Type: application/hal+json
Link: <https://github.com/SiteNetSoft/quarkus-pha/views/dashboard.json>; rel="view-descriptor"

{
  "_links": { "self": { "href": "/api/dashboard" } },
  "stats": { "revenue": 48200, "users": 1847, "orders": 312 },
  "recentActivity": [
    { "user": "alice", "action": "purchase", "item": "Widget Pro", "time": "2m ago" },
    { "user": "bob", "action": "signup", "time": "15m ago" }
  ],
  "chartData": { "labels": ["Mon","Tue","Wed","Thu","Fri"], "values": [12,19,3,5,2] }
}
```

**View Descriptor Resource** (`dashboard.json`):

```json
{
  "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/layouts/sidebar.html",
  "slots": {
    "sidebarNav": {
      "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/navigation/nav.html"
    },
    "mainContent": {
      "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/demos/dashboard.html",
      "slots": {
        "statsCards": {
          "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card.html"
        },
        "activityTable": {
          "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/table.html"
        },
        "revenueChart": {
          "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/charts/chart.html"
        }
      }
    }
  }
}
```

### 7.3 OData4 Product List

```http
HTTP/1.1 200 OK
Content-Type: application/json;odata.metadata=minimal
Link: <https://example.com/views/product-list.json>; rel="view-descriptor"

{
  "@odata.context": "https://example.com/odata/$metadata#Products",
  "value": [
    { "ProductID": 1, "Name": "Widget", "Price": 9.99 },
    { "ProductID": 2, "Name": "Gadget", "Price": 24.99 }
  ]
}
```

Data payload is pure OData4. The view descriptor is communicated entirely via the `Link` header.

### 7.4 Multiple Views (Responsive)

```json
{
  "_views": {
    "default": {
      "template": "https://example.com/templates/product-detail.html",
      "slots": {
        "gallery": {
          "template": "https://example.com/templates/components/image-carousel.html"
        },
        "reviews": {
          "template": "https://example.com/templates/components/review-list.html"
        }
      }
    },
    "compact": {
      "template": "https://example.com/templates/product-card.html"
    }
  },
  "id": 42,
  "name": "Widget Pro",
  "price": 29.99,
  "images": ["front.jpg", "side.jpg", "back.jpg"],
  "reviews": [
    { "author": "Alice", "rating": 5, "text": "Excellent!" }
  ]
}
```

### 7.5 BFF (Backend for Frontend) Pattern

A BFF receives an API response and a view descriptor. Instead of forwarding both to the browser, the BFF resolves the template tree server-side and returns rendered HTML:

```
Browser -> GET /dashboard
BFF -> GET /api/dashboard (receives data + Link header with view descriptor)
BFF -> Fetches view descriptor
BFF -> Fetches templates (with caching)
BFF -> Renders composed template tree with data (using Qute, Thymeleaf, etc.)
BFF -> Returns rendered HTML to browser
```

This is the pattern used by **quarkus-pha**: Quarkus acts as the BFF, fetching data and resolving Qute templates server-side.

## 8. Client Resolution Algorithm

1. **Extract view descriptor** from the response (check `_view`/`_views` body key, then `Link` header, then `View-Template` header).
2. **Fetch the view descriptor** if it is a URL reference (cache as appropriate).
3. **Fetch the root template** from the `template` URL.
4. **Identify slot insertion points** in the template.
5. **For each slot** declared in the view descriptor:
    a. Fetch the sub-template from its `template` URL.
    b. If the sub-template's view descriptor has `slots`, recurse (go to step 4).
    c. Insert the resolved sub-template into the slot.
6. **Render** the composed template tree with the API response data.

Clients SHOULD impose a maximum recursion depth (RECOMMENDED: 10 levels) to prevent unbounded nesting.

## 9. Error Handling

Clients and BFFs resolving view descriptors MUST handle failures gracefully. The general principle is: **prefer partial rendering over total failure**. The template tree is a best-effort composition.

### 9.1 Template Fetch Failures

When fetching a template URL fails (HTTP 404, 5xx, network error, timeout):

- Clients MUST NOT fail the entire render if a single slot's template is unavailable.
- Clients SHOULD skip the unavailable slot and render the remaining template tree.
- Clients MAY display a placeholder or the template's default slot content in place of the failed slot.
- Clients SHOULD log or report the failure for diagnostic purposes.

### 9.2 Slot Name Mismatch

When a view descriptor references a slot name that does not exist as an insertion point in the template:

- Clients MUST ignore slot assignments that do not match any insertion point in the resolved template.
- Clients SHOULD log a warning for unmatched slot names.
- Insertion points in the template that are not referenced by the view descriptor render their default content (if any).

### 9.3 Invalid View Descriptor

When a view descriptor is malformed (invalid JSON, missing required `template` field, wrong types):

- Clients MUST reject the invalid view descriptor.
- Clients SHOULD fall back to rendering the raw API data or a default error template.
- If the invalid descriptor is nested within a slot, only that slot fails — the parent template tree continues rendering.

### 9.4 Graceful Degradation

Error handling follows a principle of progressive failure:

1. A single slot failure does not prevent the rest of the template tree from rendering.
2. A root template failure prevents rendering entirely — the client falls back to raw data or a default template.
3. Clients SHOULD provide a consistent fallback experience (e.g., a standard error component) rather than rendering nothing.

## 10. Security Considerations

- **Template URL validation**: Clients MUST validate template URLs against an allowlist of trusted domains. Rendering arbitrary templates from untrusted sources is a code injection risk.
- **CORS**: Template resources served cross-origin MUST include appropriate CORS headers.
- **Content Security Policy**: Template URLs SHOULD be included in the `script-src` or `style-src` CSP directives as appropriate.
- **Template sandboxing**: Clients SHOULD render templates in a sandboxed context to prevent template injection attacks.
- **HTTPS**: Template URLs MUST use HTTPS in production. Clients SHOULD reject HTTP template URLs.

## 11. Relationship to Existing Standards

| Standard | Relationship |
|----------|-------------|
| REST | VDP extends REST responses with view metadata without modifying the resource representation itself |
| HAL (RFC draft) | VDP uses HAL's underscore convention (`_view`) for inline transport. Compatible with `_links` and `_embedded` |
| JSON-LD | VDP can coexist with `@context`/`@type` annotations. Template URLs could be expressed as JSON-LD `@id` values |
| OData4 | VDP uses OData4 instance annotations (`@View.descriptor`) or HTTP headers for compatibility |
| RFC 8288 (Web Linking) | VDP defines the `view-descriptor` link relation type for the `Link` header |
| HATEOAS | VDP is complementary — HATEOAS tells clients what actions are available, VDP tells clients how to render the result |

## 12. IANA Considerations

This specification requests registration of:

### 12.1 Link Relation Type

- **Relation Name:** `view-descriptor`
- **Description:** Refers to a VDP view descriptor resource that describes how to render the linked resource.
- **Reference:** This specification

### 12.2 Media Type

- **Type name:** application
- **Subtype name:** vdp+json
- **Required parameters:** None
- **Optional parameters:** `version`
- **Reference:** This specification

## 13. Discovery

APIs SHOULD advertise VDP support so clients can detect it programmatically.

### 13.1 OPTIONS Response

An API endpoint supporting VDP MUST include the `VDP` token in the `Allow` or a custom header in its `OPTIONS` response:

```http
OPTIONS /api/dashboard HTTP/1.1

HTTP/1.1 204 No Content
Allow: GET, HEAD, OPTIONS
VDP-Support: true
VDP-Version: 0.1
```

### 13.2 Well-Known URI

APIs MAY expose a discovery document at `/.well-known/vdp`:

```http
GET /.well-known/vdp HTTP/1.1

HTTP/1.1 200 OK
Content-Type: application/vdp+json

{
  "version": "0.1",
  "endpoints": {
    "/api/dashboard": {
      "template": "https://example.com/views/dashboard.json"
    },
    "/api/products": {
      "template": "https://example.com/views/product-list.json"
    }
  },
  "trustedTemplateDomains": [
    "https://github.com/SiteNetSoft/quarkus-pha"
  ]
}
```

This allows clients to prefetch view descriptors and preload templates before making data requests. The `trustedTemplateDomains` field provides the template URL allowlist referenced in Section 10.

### 13.3 OpenAPI Extension

For APIs documented with OpenAPI 3.x, VDP metadata can be declared using the `x-vdp` extension:

```yaml
paths:
  /api/dashboard:
    get:
      summary: Get dashboard data
      x-vdp:
        view-descriptor: "https://example.com/views/dashboard.json"
      responses:
        '200':
          description: Dashboard data
          headers:
            Link:
              description: View descriptor reference
              schema:
                type: string
```

## 14. Partial Updates

VDP does not define a "partial update" mechanism — every API response carries its own complete view descriptor for its own content. However, VDP naturally supports partial update patterns used by modern web frameworks.

### 14.1 Pattern

In interactive applications, a client may re-request data for a subset of the page (e.g., refreshing a single dashboard widget). The server returns new data with a view descriptor as usual. From VDP's perspective, there is no distinction between a "full page" response and a "partial" response — both are API responses with view descriptors.

### 14.2 Slot-Level Re-rendering

Clients MAY optimize rendering by comparing previous and current view descriptors:

1. If a slot's template URL has not changed, the cached template can be reused.
2. Only slots with changed template URLs or changed data need re-fetching and re-rendering.
3. The view descriptor's template tree structure provides natural boundaries for incremental updates.

This is a client-side optimization, not a protocol requirement. VDP does not mandate any diffing or caching behavior.

### 14.3 HTMX Integration

VDP integrates naturally with HTMX's partial page update model. VDP slots map to HTMX swap targets:

```http
GET /api/dashboard/stats HTTP/1.1
HX-Request: true

HTTP/1.1 200 OK
Content-Type: application/json
View-Template: https://example.com/templates/components/stats-row.html

{"revenue": 52400, "users": 1923, "orders": 347}
```

In a BFF architecture, the BFF resolves the view descriptor and returns rendered HTML directly:

```http
GET /dashboard/stats HTTP/1.1
HX-Request: true

HTTP/1.1 200 OK
Content-Type: text/html

<div class="stats-row">
  <div class="stat">Revenue: $52,400</div>
  <div class="stat">Users: 1,923</div>
</div>
```

The client-side HTMX attribute targets the slot's DOM element:

```html
<div hx-get="/dashboard/stats" hx-trigger="every 30s" hx-swap="innerHTML">
  <!-- VDP slot: statsRow -->
</div>
```

### 14.4 BFF Responsibility

Partial rendering logic belongs to the BFF or client, not to VDP. The protocol is the same whether the response represents a full page or a single component. The BFF decides:

- Which API endpoint to call for a partial update
- How to map the returned view descriptor to a DOM region
- Whether to re-render just the changed slot or the entire template tree

VDP's role is unchanged: declare which template renders the returned data.

---

## Design Decisions

The following questions were considered and resolved during the design of this specification:

1. **Conditional slots** (e.g., "use template A for admins, B for guests"): **Not in scope.** Authorization logic belongs on the server. The server sends different view descriptors based on the user's role. VDP is purely declarative — it describes *what* to render, not *when* or *for whom*.

2. **Template parameters** (e.g., passing `{"compact": true}` to a template): **Not in scope.** VDP declares *which* templates to use, nothing more. Configuration, styling, and data binding are the template engine's responsibility. Keeping VDP minimal ensures it works across all rendering frameworks without making assumptions about their capabilities.

3. **Data-to-template mapping** (e.g., specifying which JSON fields feed which template): **Not in scope.** Templates are responsible for extracting data from the API response using their own mechanisms (Qute expressions, JSONPath, data attributes, etc.). VDP maintains a clean separation between template selection and data binding.
