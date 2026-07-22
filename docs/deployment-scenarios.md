# Deployment Scenarios

VDP defines what a view descriptor says and how it reaches a client
([Specification Section 4](specification.md#4-transport-mechanisms)). It
deliberately does **not** define where template source text comes from: a
template URL is an *identifier* first — a stable name and cache key — and a
fetchable location only secondarily
([Section 6.3](specification.md#63-template-sources)).

The four deployments below are all fully conforming, and each pairs freely
with any transport — `Link` header, inline `_view`/`_views`, `View-Template`,
or well-known discovery. Dashed elements are outside the protocol: VDP names
templates; it never dictates where they live.

## Templates bundled with the app

![Diagram: an API sends data plus a view descriptor to the VDP client inside a mobile or desktop app, which looks templates up by URL in the bundle shipped with the app — no fetch](assets/diagrams/scenario-bundled-light.svg#only-light){ width="260" }
![Diagram: an API sends data plus a view descriptor to the VDP client inside a mobile or desktop app, which looks templates up by URL in the bundle shipped with the app — no fetch](assets/diagrams/scenario-bundled-dark.svg#only-dark){ width="260" }

Mobile and desktop apps ship their templates inside the application package.
The descriptor's template URLs act as lookup keys into that bundle, so
rendering needs no template network traffic at all, and template updates ship
with the app. Templates inside the app's own trust boundary are exempt from
the Section 10 network rules.

## A BFF resolves server-side

![Diagram: a browser requests a page from a BFF; the BFF's VDP client gets data plus a view descriptor from the API, resolves templates from a local store or cached fetches, and returns rendered HTML — no VDP in the browser](assets/diagrams/scenario-bff-light.svg#only-light){ width="430" }
![Diagram: a browser requests a page from a BFF; the BFF's VDP client gets data plus a view descriptor from the API, resolves templates from a local store or cached fetches, and returns rendered HTML — no VDP in the browser](assets/diagrams/scenario-bff-dark.svg#only-dark){ width="430" }

The backend-for-frontend is the VDP client
([Section 7.5](specification.md#75-bff-backend-for-frontend-pattern)): it
calls the API, resolves the descriptor against its local template store — or
fetches and caches — and returns finished HTML. The browser never sees VDP.

## Templates shipped with the page

![Diagram: the API sends data plus a view descriptor to a client script in the browser page, which matches template URLs against template elements delivered with the HTML](assets/diagrams/scenario-page-light.svg#only-light){ width="296" }
![Diagram: the API sends data plus a view descriptor to a client script in the browser page, which matches template URLs against template elements delivered with the HTML](assets/diagrams/scenario-page-dark.svg#only-dark){ width="296" }

The initial HTML delivers the templates themselves — for example as
`<template>` elements. A small client script matches each descriptor's
template URLs against that in-page registry, so later API responses can
re-template parts of the page without any further template requests.

## Templates fetched remotely

![Diagram: the API sends data plus a view descriptor to a client, which fetches templates by URL over HTTPS from a template server or CDN — cached, allowlisted, integrity-checked](assets/diagrams/scenario-remote-light.svg#only-light){ width="220" }
![Diagram: the API sends data plus a view descriptor to a client, which fetches templates by URL over HTTPS from a template server or CDN — cached, allowlisted, integrity-checked](assets/diagrams/scenario-remote-dark.svg#only-dark){ width="220" }

The fully networked deployment: the client fetches each template URL over
HTTPS from a template server or CDN, caching per ordinary HTTP semantics
([Section 5.2](specification.md#52-caching)). Everything in
[Section 10](specification.md#10-security-considerations) applies — the
allowlist source chain, HTTPS, and `integrity` verification. This is the
deployment the [Go demo](https://github.com/ViewDescriptorProtocol/golang-vdp-demo)
implements end to end.

---

These sources also compose: a client MAY consult several in order — an app
bundle first, say, with a remote fetch for templates the bundle lacks. In
every case the absolute template URL
([Section 5.4](specification.md#54-url-resolution)) is the template's
identity.

*[VDP]: View Descriptor Protocol
*[HAL]: Hypertext Application Language
