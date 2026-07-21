# View Descriptor Protocol (VDP)

**Status:** Working Draft
**Version:** 0.1

## Abstract

The View Descriptor Protocol (VDP) defines a standard mechanism for associating API data responses with the templates that should render them. A **view descriptor** is a JSON structure that names a root template by URL and declares which sub-templates fill its named slots. Because each slot is itself described by a view descriptor, descriptors form a recursive template tree. View descriptors can be transported via HTTP headers (for constrained formats like OData4) or inline in the response body (for flexible formats like HAL+JSON). The protocol is framework-agnostic — templates can be HTML/Qute, SwiftUI views, Compose layouts, or any other rendering format.

## 1. Problem Statement

REST APIs return structured data (JSON, XML) that carries no presentation information. Each client must decide on its own how to render that data — typically by hardcoding template choices into client code. As a result, every presentation change requires updating each client, and every client maintains its own copy of the same data-to-template mapping.

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
- **Slot**: A named insertion point in a template where a sub-template can be composed. Slot names correspond to the template's own insertion point identifiers (e.g., Qute's `{#insert slotName}`).
- **View Descriptor Resource**: A standalone JSON document containing a view descriptor, addressable by its own URL, cacheable independently of the data it describes.
- **Static Composition**: Composition written directly into a template's source — for example, a layout that always includes its `_head` partial. VDP does not describe static composition; it is internal to the template.
- **Dynamic Composition**: Composition that changes per API response — a slot whose template is chosen by the server at request time. These are the slots a view descriptor declares.

## 3. View Descriptor Format

### 3.1 Basic Structure (Single Template)

The simplest view descriptor points to a single template with no slots:

```json
{
  "template": "https://example.com/templates/article"
}
```

### 3.2 Template Composition (Slots)

When a template has named insertion points that should be filled dynamically, the view descriptor declares a `slots` object. Each key is a slot name matching an insertion point in the template, and each value is itself a view descriptor:

```json
{
  "template": "https://templates.example.com/layouts/sidebar",
  "slots": {
    "mainContent": {
      "template": "https://templates.example.com/components/data-display/card"
    },
    "sidebarNav": {
      "template": "https://templates.example.com/components/navigation/nav"
    }
  }
}
```

This tells the client: "Render `sidebar`, and fill its `mainContent` slot with `card` and its `sidebarNav` slot with `nav`."

### 3.3 Recursive Nesting

Since each slot value is itself a view descriptor, composition nests to arbitrary depth:

```json
{
  "template": "https://templates.example.com/layouts/sidebar",
  "slots": {
    "mainContent": {
      "template": "https://templates.example.com/demos/dashboard",
      "slots": {
        "statsRow": {
          "template": "https://templates.example.com/components/data-display/card"
        },
        "activityTable": {
          "template": "https://templates.example.com/components/data-display/table"
        },
        "chart": {
          "template": "https://templates.example.com/components/charts/chart",
          "slots": {
            "legend": {
              "template": "https://templates.example.com/components/charts/chart-legend"
            }
          }
        }
      }
    },
    "sidebarNav": {
      "template": "https://templates.example.com/components/navigation/nav"
    }
  }
}
```

### 3.4 Multiple Views

A single API response may offer multiple views (e.g., a summary view and a detail view, or views for different device classes). Declare them as a named map under the `views` key:

```json
{
  "views": {
    "default": {
      "template": "https://example.com/templates/product-detail"
    },
    "compact": {
      "template": "https://example.com/templates/product-card"
    },
    "mobile": {
      "template": "https://example.com/templates/product-mobile",
      "slots": {
        "gallery": {
          "template": "https://example.com/templates/components/swipe-gallery"
        }
      }
    }
  }
}
```

When only a single view is needed, the top-level object IS the view descriptor (no `views` wrapper). When multiple views are present, the `views` key wraps them.

How a client chooses among named views is out of scope: view names are agreed between server and client out of band, and the client selects based on its own context (device class, container size, user preference, etc.). A client SHOULD use the `default` view when it has no reason to select another. If no `default` view exists and the client has no basis for choosing, it MUST select one of the available views; the choice is client-defined.

### 3.5 Slot Arrays

A single slot can accept multiple templates, rendered in sequence within the insertion point. This is useful when composing multiple independent components into a single region:

```json
{
  "template": "https://templates.example.com/layouts/sidebar",
  "slots": {
    "mainContent": [
      {
        "template": "https://templates.example.com/components/data-display/card"
      },
      {
        "template": "https://templates.example.com/components/charts/chart"
      },
      {
        "template": "https://templates.example.com/components/data-display/table"
      }
    ],
    "sidebarNav": {
      "template": "https://templates.example.com/components/navigation/nav"
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
- Makes the view descriptor independently cacheable
- Builds on existing web standards ([RFC 8288](https://www.rfc-editor.org/rfc/rfc8288) Link Relations)

**For simple cases** (single template, no composition), a shorthand header is also defined:

```http
View-Template: https://example.com/templates/article
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
    "template": "https://templates.example.com/demos/dashboard",
    "slots": {
      "statsRow": {
        "template": "https://templates.example.com/components/data-display/card"
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
      "template": "https://example.com/templates/dashboard-full",
      "slots": { "..." : "..." }
    },
    "widget": {
      "template": "https://example.com/templates/dashboard-widget"
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

If both `_view` and `_views` appear in the same response, `_views` takes precedence and `_view` MUST be ignored.

Servers MUST NOT emit more than one `Link` header field value with `rel="view-descriptor"` in a single response. If a client nevertheless receives multiple, it MUST use the first such value (in field order, per [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110) Section 5.3) and ignore the rest.

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
  "template": "https://example.com/templates/dashboard",
  "slots": { "..." : "..." }
}
```

Template URLs themselves are also cacheable resources. Clients SHOULD cache resolved templates according to their HTTP caching headers.

### 5.3 Versioning

This section covers versioning of individual view descriptor resources (e.g., revision 2 of the dashboard view). It is distinct from the VDP protocol version, which is carried by the `version` parameter of the `application/vdp+json` media type (Section 12.2) and the discovery mechanisms (Section 13).

View descriptor resources are versioned by URL convention:

```
https://example.com/views/v2/dashboard.json
https://example.com/views/dashboard.json?v=2
```

Servers MUST NOT use the media type `version` parameter to version individual view descriptor resources — it identifies the protocol version, not a resource revision.

### 5.4 URL Resolution

Template URLs in a view descriptor MAY be relative references (RFC 3986 Section 4.2). Clients MUST resolve relative URLs against a base URL determined by the transport that delivered the descriptor:

1. **Standalone view descriptor resource**: The URL of the view descriptor resource itself (i.e., the URL used to fetch it via the `Link` header).
2. **Inline transport** (`_view` / `_views`): The URL of the API response containing the view descriptor.
3. **`View-Template` header**: The URL of the API response carrying the header.

Nested slot template URLs resolve against the same base URL as the root template URL — the base does not change at each nesting level.

**Example:**

Given an API response at `https://example.com/api/dashboard` with an inline view descriptor:

```json
{
  "_view": {
    "template": "/templates/layouts/sidebar",
    "slots": {
      "mainContent": {
        "template": "/templates/components/card"
      }
    }
  }
}
```

Both template URLs resolve against `https://example.com/api/dashboard`:
- `/templates/layouts/sidebar` → `https://example.com/templates/layouts/sidebar`
- `/templates/components/card` → `https://example.com/templates/components/card`

Note that resolution follows RFC 3986 exactly: a reference without a leading slash resolves relative to the base URL's path, so `templates/components/card` would yield `https://example.com/api/templates/components/card` instead.

Servers SHOULD use absolute URLs when view descriptors may be consumed by multiple clients with different base URL contexts.

### 5.5 Client-Specific Selection

When different clients require different templates (e.g., HTML for web, Compose for Android, SwiftUI for iOS), the server SHOULD use standard HTTP content negotiation to select the appropriate view descriptor. VDP does not define a mechanism for shipping multiple platform variants in a single response — the server selects and returns one view descriptor per request.

Negotiation applies to whichever request returns the view descriptor: the fetch of the standalone view descriptor resource (Section 4.1), or the API request itself when the descriptor is inline (Section 4.2). Servers MAY use custom headers or query parameters to determine the client's rendering platform:

```http
GET /views/dashboard.json HTTP/1.1
Accept: application/vdp+json
VDP-Platform: android
```

(The header is named `VDP-Platform`, not `X-VDP-Platform` — the `X-` prefix convention is deprecated by [RFC 6648](https://www.rfc-editor.org/rfc/rfc6648).)

This keeps view descriptors small and avoids pushing selection logic into clients.

## 6. Template Requirements

VDP is agnostic to the template language. However, a template used with VDP MUST meet one requirement: **it exposes named insertion points (slots) that can be filled from outside the template**.

### 6.1 Framework Slot Mappings

| Framework         | Slot Mechanism                  | Example                                 |
|-------------------|---------------------------------|-----------------------------------------|
| Qute              | `{#insert slotName}{/insert}`   | `{#insert mainContent}Default{/insert}` |
| Thymeleaf         | `th:fragment` / `th:replace`    | `<div th:replace="~{slotName}"></div>`  |
| JSX/React         | `props.children` or named props | `{props.mainContent}`                   |
| SwiftUI           | `@ViewBuilder` parameters       | `var mainContent: () -> Content`        |
| Jetpack Compose   | `@Composable` slot parameters   | `mainContent: @Composable () -> Unit`   |

### 6.2 Static vs Dynamic Slots

Not every insertion point in a template needs to appear in the view descriptor. Templates commonly include partials that never change — a shared `_head`, a footer — and those stay hardcoded in the template (static composition, Section 2). Only slots whose content varies per API response belong in the view descriptor (dynamic composition).

## 7. Examples

### 7.1 Login Page (Simple, No Slots)

**API Response:**

```http
HTTP/1.1 200 OK
Content-Type: application/json
View-Template: https://templates.example.com/components/forms/form

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
Link: <https://example.com/views/dashboard.json>; rel="view-descriptor"

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
  "template": "https://templates.example.com/layouts/sidebar",
  "slots": {
    "sidebarNav": {
      "template": "https://templates.example.com/components/navigation/nav"
    },
    "mainContent": {
      "template": "https://templates.example.com/demos/dashboard",
      "slots": {
        "statsCards": {
          "template": "https://templates.example.com/components/data-display/card"
        },
        "activityTable": {
          "template": "https://templates.example.com/components/data-display/table"
        },
        "revenueChart": {
          "template": "https://templates.example.com/components/charts/chart"
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
      "template": "https://example.com/templates/product-detail",
      "slots": {
        "gallery": {
          "template": "https://example.com/templates/components/image-carousel"
        },
        "reviews": {
          "template": "https://example.com/templates/components/review-list"
        }
      }
    },
    "compact": {
      "template": "https://example.com/templates/product-card"
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
    b. If the slot's view descriptor itself declares `slots`, repeat steps 3–5 for that descriptor.
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
- For slot arrays (Section 3.5), a failed array element is skipped; the remaining elements render in their declared order.
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

Error handling follows the principle that a failure stays as local as possible:

1. A single slot failure does not prevent the rest of the template tree from rendering.
2. A root template failure prevents rendering entirely — the client falls back to raw data or a default template.
3. Clients SHOULD provide a consistent fallback experience (e.g., a standard error component) rather than rendering nothing.

## 10. Security Considerations

- **Template URL validation**: Clients MUST validate template URLs against an allowlist of trusted URL prefixes. Rendering arbitrary templates from untrusted sources is a code injection risk. The allowlist is determined by the first available source below:
  1. **Local configuration** — an allowlist configured in the client or its deployment. When present, it takes precedence over anything the server advertises.
  2. **Discovery document** — the `trustedTemplateUrls` member of the API's discovery document (Section 13.2), when one is available.
  3. **Same-origin default** — when neither of the above is available, only template URLs sharing an origin ([RFC 6454](https://www.rfc-editor.org/rfc/rfc6454)) with the view descriptor's base URL (Section 5.4) are trusted.

  Matching semantics for allowlist entries are defined in Section 13.2.
- **CORS**: Template resources served cross-origin MUST include appropriate CORS headers.
- **Content Security Policy**: Browser clients fetching templates at runtime SHOULD include template origins in the `connect-src` CSP directive. `script-src` or `style-src` apply only where templates are loaded as executable scripts or stylesheets.
- **Template sandboxing**: Clients SHOULD render templates in a sandboxed context to prevent template injection attacks.
- **HTTPS**: Template URLs MUST use HTTPS. Clients SHOULD reject `http:` template URLs, with an exception permitted for loopback addresses during local development.

## 11. Relationship to Existing Standards

| Standard | Relationship |
|----------|-------------|
| REST | VDP extends REST responses with view metadata without modifying the resource representation itself |
| HAL (RFC draft) | VDP uses HAL's underscore convention (`_view`) for inline transport. Compatible with `_links` and `_embedded` |
| JSON-LD | VDP can coexist with `@context`/`@type` annotations. Template URLs could be expressed as JSON-LD `@id` values |
| OData4 | VDP uses OData4 instance annotations (`@View.descriptor`) or HTTP headers for compatibility |
| [RFC 8288](https://www.rfc-editor.org/rfc/rfc8288) (Web Linking) | VDP defines the `view-descriptor` link relation type for the `Link` header |
| HATEOAS | VDP is complementary — HATEOAS tells clients what actions are available, VDP tells clients how to render the result |

## 12. IANA Considerations

This specification requests registration of the entries below. None of these registrations have been submitted to IANA yet; until they are, `view-descriptor` acts as an extension relation type (RFC 8288 Section 2.1.2) and the media types are provisional.

### 12.1 Link Relation Type

- **Registry:** IANA Link Relation Types ([RFC 8288](https://www.rfc-editor.org/rfc/rfc8288))
- **Relation Name:** `view-descriptor`
- **Description:** Refers to a VDP view descriptor resource that describes how to render the linked resource.
- **Reference:** This specification

### 12.2 Media Type

- **Type name:** application
- **Subtype name:** vdp+json
- **Required parameters:** None
- **Optional parameters:** `version` — the VDP protocol version the payload conforms to (e.g., `application/vdp+json; version=0.1`). This is the same value advertised by the `VDP-Version` header and the well-known discovery document (Section 13). It does not version individual view descriptor resources (see Section 5.3).
- **Reference:** This specification

### 12.3 Media Type: `application/vdp-discovery+json`

- **Type name:** application
- **Subtype name:** vdp-discovery+json
- **Required parameters:** None
- **Optional parameters:** None
- **Encoding considerations:** Same as `application/json`; uses the `+json` structured syntax suffix ([RFC 6839](https://www.rfc-editor.org/rfc/rfc6839))
- **Reference:** This specification (Section 13.2)

### 12.4 Well-Known URI

- **Registry:** IANA Well-Known URIs ([RFC 8615](https://www.rfc-editor.org/rfc/rfc8615))
- **URI suffix:** `vdp`
- **Reference:** This specification (Section 13.2)

### 12.5 HTTP Field Names

- **Registry:** Hypertext Transfer Protocol (HTTP) Field Name Registry ([RFC 9110](https://www.rfc-editor.org/rfc/rfc9110) Section 16.3.1)
- **Field names:**

| Field Name      | Status      | Reference                    |
|-----------------|-------------|------------------------------|
| `View-Template` | provisional | This specification (§4.1)    |
| `VDP-Support`   | provisional | This specification (§13.1)   |
| `VDP-Version`   | provisional | This specification (§13.1)   |
| `VDP-Platform`  | provisional | This specification (§5.5)    |

## 13. Discovery

APIs SHOULD advertise VDP support so clients can detect it programmatically.

### 13.1 OPTIONS Response

An API endpoint supporting VDP SHOULD advertise it in its `OPTIONS` response, using the `VDP-Support` and `VDP-Version` headers:

```http
OPTIONS /api/dashboard HTTP/1.1

HTTP/1.1 204 No Content
Allow: GET, HEAD, OPTIONS
VDP-Support: true
VDP-Version: 0.1
```

The presence of `VDP-Version` alone is sufficient to signal VDP support; `VDP-Support` is an explicit affirmation retained for readability. Servers SHOULD send both, but clients MUST treat a response carrying only `VDP-Version` as advertising support.

### 13.2 Well-Known URI

APIs MAY expose a discovery document at `/.well-known/vdp` ([RFC 8615](https://www.rfc-editor.org/rfc/rfc8615)):

```http
GET /.well-known/vdp HTTP/1.1
Accept: application/vdp-discovery+json

HTTP/1.1 200 OK
Content-Type: application/vdp-discovery+json

{
  "version": "0.1",
  "endpoints": {
    "/api/dashboard": {
      "descriptor": "https://example.com/views/dashboard.json"
    },
    "/api/products": {
      "descriptor": "https://example.com/views/product-list.json"
    },
    "/api/products/{id}": {
      "descriptor": "/views/product-detail.json"
    }
  },
  "trustedTemplateUrls": [
    "https://templates.example.com/"
  ]
}
```

The discovery document is not a view descriptor and MUST NOT be served as `application/vdp+json`. It is served as `application/vdp-discovery+json` (Section 12.3); clients SHOULD also accept `application/json` from servers that cannot configure custom media types.

Each entry in `endpoints` maps an API path to the URL of its view descriptor resource (`descriptor`). This allows clients to prefetch view descriptors and preload templates before making data requests.

**Endpoint keys** are absolute paths (beginning with `/`), interpreted relative to the origin serving the discovery document. A key MAY be a Level 1 URI Template ([RFC 6570](https://www.rfc-editor.org/rfc/rfc6570)), e.g. `/api/products/{id}`. When matching a request path against templated keys, each expression matches exactly one path segment — one or more characters, none of which is `/`. If a path matches multiple entries, a literal (non-templated) entry takes precedence over a templated one; the result of a path matching multiple templated entries is undefined, and servers SHOULD NOT publish overlapping templated keys.

**Descriptor URLs** (`descriptor` values) MAY be relative references, resolved against the URL of the discovery document itself per [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986) Section 5 (so `/views/product-detail.json` above resolves against `https://example.com/.well-known/vdp` to `https://example.com/views/product-detail.json`).

**Caching:** the discovery document is an ordinary cacheable resource. Servers SHOULD provide standard HTTP caching headers (`Cache-Control`, `ETag`) on it, as they do for view descriptor resources (Section 5.2).

The `endpoints` member is intentionally aligned in spirit with [RFC 9264](https://www.rfc-editor.org/rfc/rfc9264) (Linkset): each entry expresses a `view-descriptor` link (Section 12.1) whose context is the API path and whose target is the descriptor URL. Linkset itself is not used because it defines no document-level members for metadata such as `version` and `trustedTemplateUrls`. A future version of this specification may additionally offer the same links as `application/linkset+json`.

The `trustedTemplateUrls` field provides the template URL allowlist referenced in Section 10. Each entry is a URL prefix: a template URL is trusted if and only if, after RFC 3986 normalization, it begins with one of the listed entries. Entries SHOULD end with a trailing slash so that `https://templates.example.com/` cannot accidentally match `https://templates.example.com.evil.host/`.

**Extensibility:** Clients MUST ignore members of the discovery document — including members of `endpoints` entries — that they do not recognize. Future versions of this specification may define additional members.

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
View-Template: https://example.com/templates/components/stats-row

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

*[VDP]: View Descriptor Protocol
*[HAL]: Hypertext Application Language
