# Examples

These are the canonical VDP examples. Each validates against the [VDP v0.1 schema](schema.md).

## Simple View Descriptor

The simplest possible view descriptor: a single template with no slots.

**Use case:** A login form, a static page, or any endpoint that maps to a single template.

```json title="vdp-simple.json"
{
  "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/forms/form"
}
```

The server might deliver this via the `View-Template` HTTP header:

```http
HTTP/1.1 200 OK
Content-Type: application/json
View-Template: https://github.com/SiteNetSoft/quarkus-pha/templates/components/forms/form

{"csrfToken": "abc123", "loginUrl": "/auth/login"}
```

---

## Composed View Descriptor

A layout template with nested slots, forming a template tree. The sidebar layout has two slots: `sidebarNav` for navigation, and `mainContent` for a dashboard that itself contains three further slots.

**Use case:** A dashboard page with a sidebar navigation, stats cards, an activity table, and a chart.

```json title="vdp-composed.json"
{
  "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/layouts/sidebar",
  "slots": {
    "sidebarNav": {
      "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/navigation/nav"
    },
    "mainContent": {
      "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/demos/dashboard",
      "slots": {
        "statsCards": {
          "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card"
        },
        "activityTable": {
          "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/table"
        },
        "revenueChart": {
          "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/charts/chart"
        }
      }
    }
  }
}
```

The resulting template tree:

```
sidebar
├── sidebarNav → nav
└── mainContent → dashboard
    ├── statsCards → card
    ├── activityTable → table
    └── revenueChart → chart
```

This descriptor would typically be served as a standalone resource referenced via `Link` header:

```http
Link: <https://example.com/views/dashboard.json>; rel="view-descriptor"
```

---

## Multi-View Descriptor

Multiple named views for the same API response. The client selects a view based on context (device class, user preference, layout mode).

**Use case:** A product page with a full detail view and a compact card view.

```json title="vdp-multi-view.json"
{
  "views": {
    "default": {
      "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/demos/dashboard",
      "slots": {
        "statsCards": {
          "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card"
        },
        "activityTable": {
          "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/table"
        }
      }
    },
    "compact": {
      "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card"
    }
  }
}
```

Clients SHOULD use the `default` view when no specific view is requested. When embedded inline, use the `_views` key:

```json
{
  "_views": {
    "default": { "..." : "..." },
    "compact": { "..." : "..." }
  },
  "revenue": 48200,
  "users": 1847
}
```

---

## Slot Array

A single slot accepting multiple templates rendered in sequence. Each element is a full view descriptor.

**Use case:** A main content area that renders a card, chart, and table in order.

```json title="vdp-slot-array.json"
{
  "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/layouts/sidebar",
  "slots": {
    "mainContent": [
      {
        "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card"
      },
      {
        "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/charts/chart"
      },
      {
        "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/table"
      }
    ],
    "sidebarNav": {
      "template": "https://github.com/SiteNetSoft/quarkus-pha/templates/components/navigation/nav"
    }
  }
}
```

The `mainContent` slot receives an array of three view descriptors. The client MUST render them in order:

1. `card`
2. `chart`
3. `table`

Each array element can itself contain nested `slots` for further composition.
