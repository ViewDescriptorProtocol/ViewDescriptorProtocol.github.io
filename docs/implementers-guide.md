# Implementers Guide

This guide walks through building a working VDP implementation. The
[specification](specification.md) defines *what* conforms; this page is about
*how* — the order to build things in, the decisions you will hit, and the
mistakes that are easy to make.

The spec defines three [conformance classes](specification.md#15-conformance),
and an implementation may belong to more than one:

| Class | Role | You are building… |
|-------|------|-------------------|
| [**VDP Server**](specification.md#151-vdp-server) | Produces view descriptors | an API that tells clients which templates render its responses |
| [**VDP Client**](specification.md#152-vdp-client) | Consumes view descriptors | a renderer that resolves descriptors into template trees |
| [**VDP BFF**](specification.md#153-vdp-bff) | A client that renders server-side | a backend-for-frontend returning finished markup |

The [Go demo](https://github.com/ViewDescriptorProtocol/golang-vdp-demo)
implements all three in one process and is the reference to read alongside this
guide — its `vdp` package is a complete client, its `server` package a complete
server and BFF.

---

## Implementing a VDP Server

A server's job is small by design: attach a descriptor to each response. It
never fetches templates and never renders.

### 1. Shape your descriptors

A view descriptor names a root template and, optionally, the sub-templates
filling its named slots:

```json
{
  "template": "example.com/templates/layouts/sidebar",
  "slots": {
    "mainContent": { "template": "example.com/templates/dashboard" },
    "sidebarNav":  { "descriptor": "/views/nav.json" }
  }
}
```

Every descriptor you emit MUST validate against the
[published schema](schema.md). Wire that into CI from day one — it is the
cheapest conformance test you will ever write:

```bash
npx ajv-cli test --spec=draft2020 \
  -s vdp.v0-1.schema.json -d 'views/*.json' --valid -c ajv-formats
```

### 2. Choose an identifier form

A template URI is an **identity first** — a stable name and cache key — and a
fetchable location only secondarily
([Section 6.3](specification.md#63-template-sources)). The spec defines three
forms ([Section 5.4](specification.md#54-url-resolution)):

| Form | Example | Behavior |
|------|---------|----------|
| **(a) Absolute URI** | `https://example.com/templates/card` | Identity as written |
| **(b) Relative reference** — begins with `/` or `//` | `/templates/card` | Resolved against the transport's base URL |
| **(c) Scheme-less opaque identifier** | `example.com/templates/card` | Identity as written; **never resolved against a base** |

Guidance:

- Use **absolute URIs** when descriptors may be consumed from multiple base URL
  contexts (the spec's own SHOULD).
- Use **path-absolute references** when templates live on the same origin as
  the API — descriptors stay portable across your environments (dev, staging,
  production) because the base URL travels with the transport.
- Use **opaque identifiers** when the URI is a *name* more than an address —
  package-import-style identities that clients look up in a bundle or registry,
  supplying a scheme only if they actually fetch.

Whatever you choose, remember that dot-relative values (`../templates/card`)
fit **no** form: anything scheme-less that does not begin with `/` is an opaque
identifier, so a conforming client will treat `..` as a host and reject it. Do
not emit them.

### 3. Choose a transport

Any one of the [Section 4](specification.md#4-transport-mechanisms) transports
satisfies conformance; which fits depends on how much you control the response
body:

| Your response body is… | Use | Example |
|------------------------|-----|---------|
| Flexible JSON (HAL, custom) | Inline `_view` / `_views` | `{"_view": {...}, "revenue": 48200}` |
| Rigid (OData4, third-party formats) | `Link` header to a standalone descriptor resource | `Link: <https://example.com/views/dashboard.json>; rel="view-descriptor"` |
| Rendered by exactly one template | `View-Template` header shorthand | `View-Template: example.com/templates/login` |

Two transport rules trip people up:

- Emit **at most one** `Link` value with `rel="view-descriptor"` per response
  ([Section 4.4](specification.md#44-precedence)); clients take the first.
- When both an inline descriptor and a `Link` header are present, the body wins
  — so do not send both expecting the header to override.

### 4. Serve descriptor resources well

A standalone descriptor is an ordinary cacheable resource
([Section 5](specification.md#5-view-descriptor-resources)). Serve it as
`application/vdp+json` with real caching headers, and advertise the protocol
version:

```http
HTTP/1.1 200 OK
Content-Type: application/vdp+json
Cache-Control: public, max-age=3600
ETag: "v1-dashboard"
VDP-Version: 0.1
```

Independent cacheability is the point: the descriptor changes when the
*presentation* changes, the data endpoint when the *data* does.

### 5. Publish discovery

A discovery document at `/.well-known/vdp`
([Section 13.2](specification.md#132-well-known-uri)) lets clients prefetch
descriptors and learn your template allowlist:

```json
{
  "version": "0.1",
  "endpoints": {
    "/api/dashboard":     { "descriptor": "/views/dashboard.json" },
    "/api/products/{id}": { "descriptor": "/views/product-detail.json" }
  },
  "trustedTemplateUrls": [
    "https://example.com/templates/",
    "example.com/templates/"
  ]
}
```

- Serve it as `application/vdp-discovery+json` — never as
  `application/vdp+json`.
- End allowlist entries with a trailing slash, so `…/templates/` cannot match
  `…/templates-evil/`.
- Allowlist matching never crosses identifier forms: an absolute entry matches
  only absolute URIs, a scheme-less entry only opaque identifiers. **List each
  form you actually emit** — the example above lists both.
- Endpoint keys may be Level 1 URI Templates; each `{expression}` matches one
  path segment, and literal keys win over templated ones.

### 6. Add template metadata where it earns its keep

`type` is an advisory media-type hint; `integrity` is W3C Subresource
Integrity for the template bytes
([Section 3.6](specification.md#36-optional-template-metadata)). Publish
`integrity` for templates hosted on infrastructure you don't control — it
authenticates the *content* where the allowlist only authenticates the
*origin*:

```json
{
  "template": "https://cdn.example.net/templates/chart-legend",
  "type": "text/x-qute",
  "integrity": "sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxy9rx7HNQlGYl1kPzQho1wx4JwY8wC"
}
```

The digest is computed over the exact bytes clients will fetch —
`base64(sha384(body))`.

### Server checklist

- [ ] Every descriptor validates against the published JSON Schema
- [ ] At least one Section 4 transport, following its rules (one `Link` value max)
- [ ] Descriptor resources served as `application/vdp+json` with caching headers
- [ ] Absolute template URIs where descriptors cross base-URL contexts
- [ ] Discovery document valid per Section 13.2, served as `application/vdp-discovery+json`
- [ ] Allowlist entries end with `/` and cover every identifier form emitted

---

## Implementing a VDP Client

A client does the real work: extract, resolve, obtain, compose, render —
the [Section 8 algorithm](specification.md#8-client-resolution-algorithm).
Build it in this order.

### 1. Extract the descriptor

Check the response in [precedence order](specification.md#44-precedence):
`_view` / `_views` in the body first, then the `Link` header
(`rel="view-descriptor"`, first value), then `View-Template`. Record which
transport won — it determines the **base URL** for relative references:

| Transport | Base URL for `/…` references |
|-----------|------------------------------|
| Standalone descriptor resource (`Link`) | the descriptor resource's own URL |
| Inline `_view` / `_views` | the API response's URL |
| `View-Template` header | the API response's URL |

A malformed descriptor is rejected outright
([Section 9.3](specification.md#93-invalid-view-descriptor)) — fall back to
raw data rather than guessing at partial meaning.

### 2. Classify every template URI

This is the step implementations get wrong. Classify each value **before**
touching a URL library:

```text
has a scheme        →  form (a): identity = the value, as written
begins with "/"     →  form (b): identity = resolve(value, base)
anything else       →  form (c): identity = the value, as written — opaque
```

!!! warning "Never resolve an opaque identifier against the base URL"

    General-purpose URL resolution treats `example.com/templates/card` as a
    *relative path*. Resolved against `https://api.example.org/dashboard`, it
    silently becomes `https://api.example.org/example.com/templates/card` — a
    corrupted identity that may even pass a sloppy allowlist before 404ing.
    The spec forbids this: a scheme-less value not beginning with `/` names
    the template directly and is compared and cached **verbatim**.

    Watch your standard library, too: Go's `url.Parse` errors on
    `127.0.0.1:8080/templates/card` ("first path segment in URL cannot
    contain colon"), and JavaScript's `new URL(value, base)` happily
    mis-resolves it. Branch on the form first; parse afterwards.

The identity from this step — resolved absolute URL or verbatim opaque
identifier — is the template's **cache key and comparison key** everywhere
downstream. A scheme is supplied only if and when you fetch
([Section 6.3](specification.md#63-template-sources)).

### 3. Obtain templates — from anywhere

The identifier tells you *which* template; your deployment decides *where its
source text comes from*. All of these are equally conforming
([Section 6.3](specification.md#63-template-sources), and see the
[deployment scenarios](deployment-scenarios.md)):

- a bundle shipped inside the application package,
- `<template>` elements delivered with the page,
- a store local to the BFF or a template service,
- a network fetch of the template URI itself.

Select by identity, whatever the source — a template satisfied locally is
indistinguishable, to the rest of the algorithm, from a fetch whose cache was
warm. Network fetch is the interoperable default when no local source has the
template, and every network retrieval is subject to Section 10.

### 4. Enforce trust before any fetch

Rendering arbitrary templates is code injection. Before fetching, validate the
*identity* against the [Section 10](specification.md#10-security-considerations)
allowlist chain — first source available wins:

1. **Local configuration** — your own allowlist, when present.
2. **Discovery document** — the API's `trustedTemplateUrls`.
3. **Same-origin default** — only identities sharing the descriptor's origin.

Matching ([Section 13.2](specification.md#132-well-known-uri)) is prefix
matching after normalization. Practical notes:

- Compare on path-segment boundaries, so a `…/templates` entry does not match
  `…/templates-evil`.
- Lowercase the scheme and host before comparing; paths stay case-sensitive.
- Forms never cross-match: opaque identifiers match only scheme-less entries,
  absolute URIs only absolute entries.
- Reject *before* fetching. An untrusted template must never be
  fetched-then-discarded.

And the transport rule: network retrieval MUST use HTTPS, with plain HTTP
acceptable only for loopback during development. Templates from inside your
own trust boundary (a bundle, the page) are exempt from all of Section 10.

### 5. Verify integrity

When a descriptor carries `integrity`, verify any template you fetched over
the network against it — W3C SRI semantics: strongest algorithm present wins,
any one matching digest of that algorithm passes, unknown algorithms are
ignored. A mismatch **is a fetch failure** for that slot
([Section 9.1](specification.md#91-template-fetch-failures)), not a warning.

### 6. Compose, and fail small

Walk the descriptor recursively — obtain the root template, fill each slot,
recurse ([Section 8](specification.md#8-client-resolution-algorithm)) — under
the principle **prefer partial rendering over total failure**
([Section 9](specification.md#9-error-handling)):

- A slot whose template cannot be obtained is **skipped**; the template's
  default content shows instead. The rest of the tree still renders.
- A failed element of a slot *array* is skipped; the remaining elements render
  in declared order.
- Only a **root** template failure fails the render — fall back to raw data or
  an error template.
- Slot names with no matching insertion point are ignored (log them).
- Impose a recursion depth limit (10 is the recommendation); descriptor
  references count toward it, and a reference chain that revisits a URL is a
  cycle that abandons just that slot.

Cache aggressively ([Section 5.2](specification.md#52-caching)): descriptors
and templates are ordinary HTTP resources, keyed by identity.

### Client checklist

- [ ] Extraction follows Section 4.4 precedence
- [ ] The three Section 5.4 identifier forms classified correctly — opaque ids never base-resolved
- [ ] Templates selected and cached by identity, from any Section 6.3 source
- [ ] Allowlist chain enforced before every network fetch; no cross-form matching
- [ ] HTTPS enforced for network retrieval (loopback excepted)
- [ ] `integrity` verified when present; mismatch treated as fetch failure
- [ ] Partial rendering on slot failure; fallback on root failure; depth limit and cycle detection
- [ ] Invalid descriptors rejected; unrecognized discovery members ignored

---

## Implementing a VDP BFF

A BFF is a VDP Client that runs server-side
([Section 7.5](specification.md#75-bff-backend-for-frontend-pattern)): it
meets **every** client requirement above in its role as consumer of upstream
APIs, then returns finished markup. VDP places no constraints on the interface
it exposes downstream — the browser never sees a descriptor.

What changes in practice:

- **Negotiate for your platform.** Send `VDP-Platform` (and standard content
  negotiation) on descriptor fetches so the API can select the right template
  tree ([Section 5.5](specification.md#55-client-specific-selection)).
- **Cache across users.** Descriptors and templates are shared, cacheable
  state; per their HTTP headers, one warm cache serves every request.
- **Keep failure behavior.** Section 9's partial rendering applies to the page
  you assemble: a dead slot ships as the template's default, not as a 500.

---

## Testing your implementation

**Servers:** schema-validate every descriptor and discovery document you emit
(the [ajv commands](schema.md#validation) mirror the spec repo's CI), then
check the transport rules — exactly one `Link` value, correct media types,
`VDP-Version` where you advertise support.

**Clients:** the hard cases are the failure paths and the identifier forms.
The [Go demo](https://github.com/ViewDescriptorProtocol/golang-vdp-demo)
serves ready-made vectors — run it locally and point your client at:

| Endpoint | Exercises | Your client should |
|----------|-----------|--------------------|
| `/api/dashboard` | Link transport, form (b) refs, §3.7 reference, integrity | Render a four-level tree |
| `/api/dashboard?fail=chart` | One slot's template 404s | Skip the slot, render the rest |
| `/api/dashboard?fail=root` | Root template 404s | Fall back to raw data |
| `/api/dashboard?fail=integrity` | SRI mismatch | Treat as fetch failure, skip the slot |
| `/api/dashboard?untrusted` | Off-allowlist template | Reject **without fetching** |
| `/api/odata/products` | Link + OData annotation, form (c) opaque identifier | Keep the identifier verbatim as cache key |
| `/api/login` | `View-Template` shorthand | Render the single template |
| `/api/products/42?view=compact` | Multiple named views | Select the requested view, default otherwise |

And remember what is deliberately **not** VDP's job — do not build it into
your implementation: conditional slot logic, template parameters, and
data-to-template field mapping all belong to the server's descriptor choice or
the template engine, never to the protocol
([Design Decisions](specification.md#design-decisions)).

*[VDP]: View Descriptor Protocol
*[HAL]: Hypertext Application Language
*[BFF]: Backend for Frontend
*[SRI]: Subresource Integrity
