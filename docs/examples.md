# Examples

These are the canonical VDP examples. Each validates against the [VDP v0.2 schema](schema.md).

## Simple View Descriptor

The simplest possible view descriptor: a single template with no slots.

**Use case:** A login form, a static page, or any endpoint that maps to a single template.

```json title="vdp-simple.json"
{
  "template": "github.com/SiteNetSoft/quarkus-pha/templates/components/forms/form"
}
```

The server might deliver this via the `View-Template` HTTP header:

```http
HTTP/1.1 200 OK
Content-Type: application/json
View-Template: github.com/SiteNetSoft/quarkus-pha/templates/components/forms/form

{"csrfToken": "abc123", "loginUrl": "/auth/login"}
```

---

## Composed View Descriptor

A layout template with nested slots, forming a template tree. The sidebar layout has two slots: `sidebarNav` for navigation and `mainContent` for a dashboard that itself contains three further slots.

**Use case:** A dashboard page with a sidebar navigation, stats cards, an activity table, and a chart.

```json title="vdp-composed.json"
{
  "template": "github.com/SiteNetSoft/quarkus-pha/templates/layouts/sidebar",
  "slots": {
    "sidebarNav": {
      "template": "github.com/SiteNetSoft/quarkus-pha/templates/components/navigation/nav"
    },
    "mainContent": {
      "template": "github.com/SiteNetSoft/quarkus-pha/templates/demos/dashboard",
      "slots": {
        "statsCards": {
          "template": "github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card"
        },
        "activityTable": {
          "template": "github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/table"
        },
        "revenueChart": {
          "template": "github.com/SiteNetSoft/quarkus-pha/templates/components/charts/chart"
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

**Use case:** A dashboard with a full detail view and a compact card view.

```json title="vdp-multi-view.json"
{
  "views": {
    "default": {
      "template": "github.com/SiteNetSoft/quarkus-pha/templates/demos/dashboard",
      "slots": {
        "statsCards": {
          "template": "github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card"
        },
        "activityTable": {
          "template": "github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/table"
        }
      }
    },
    "compact": {
      "template": "github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card"
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
  "template": "github.com/SiteNetSoft/quarkus-pha/templates/layouts/sidebar",
  "slots": {
    "mainContent": [
      {
        "template": "github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/card"
      },
      {
        "template": "github.com/SiteNetSoft/quarkus-pha/templates/components/charts/chart"
      },
      {
        "template": "github.com/SiteNetSoft/quarkus-pha/templates/components/data-display/table"
      }
    ],
    "sidebarNav": {
      "template": "github.com/SiteNetSoft/quarkus-pha/templates/components/navigation/nav"
    }
  }
}
```

The `mainContent` slot receives an array of three view descriptors. The client MUST render them in order:

1. `card`
2. `chart`
3. `table`

Each array element can itself contain nested `slots` for further composition.


## Transforms

Each node MAY declare a `transform` (Specification Section 3.8) adapting the response representation into the model its template expects. Every transform reads the **original** response — never an ancestor's transform output:

```json title="vdp-transform.json"
{
  "template": "example.com/templates/layouts/sidebar",
  "slots": {
    "sidebarNav": {
      "template": "example.com/templates/components/navigation/nav",
      "transform": { "items": "/_links" }
    },
    "mainContent": {
      "template": "example.com/templates/demos/dashboard",
      "slots": {
        "statsCards": {
          "template": "example.com/templates/components/data-display/card",
          "transform": {
            "cards": {
              "$entries": "/stats",
              "$to": { "label": "/key", "value": "/value" }
            }
          }
        },
        "activityTable": {
          "template": "example.com/templates/components/data-display/table",
          "transform": {
            "columns": { "$get": "/columns", "$default": ["user", "action", "item", "time"] },
            "rows": "/recentActivity"
          }
        },
        "revenueChart": {
          "template": "example.com/templates/components/charts/chart",
          "transform": { "labels": "/chartData/labels", "series": "/chartData/values" }
        }
      }
    }
  }
}
```

The `card` template's contract is `{"cards": [{"label", "value"}]}` no matter which API feeds it. Nodes without a transform (the layout, the dashboard) receive the representation unchanged.

Where declarative reshaping is not enough, a `$mapper` references mapping code the client has registered — an identifier matched verbatim, never fetched:

```json title="vdp-transform-mapper.json"
{
  "template": "example.com/templates/data-table",
  "transform": { "$mapper": "https://example.com/mappers/dataset-to-table" }
}
```
