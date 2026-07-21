# Changelog

All notable changes to the View Descriptor Protocol (VDP) specification are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The specification is in early working draft; entries below track changes to the v0.1 draft until its first tagged release.

## [0.1.0] — Working Draft (unreleased)

### Added

- VDP specification (`view-descriptor-protocol.md`): view descriptor format with recursive slots, slot arrays, multiple named views, transport via inline `_view`/`_views` or HTTP `Link` headers (`rel="view-descriptor"`) and the `View-Template` shorthand, OData4 instance annotations, caching and versioning of descriptor resources, client resolution algorithm, error handling, security considerations, discovery (`OPTIONS` headers, `/.well-known/vdp`, OpenAPI `x-vdp` extension), and partial update patterns.
- JSON Schemas (2020-12 dialect): `vdp.v0-1.schema.json` validating `ViewDescriptor` and `MultiViewDescriptor` payloads, and `vdp-discovery.v0-1.schema.json` validating the `/.well-known/vdp` discovery document.
- Canonical examples (`examples/vdp-*.json`, `examples/discovery-*.json`), validated against the schemas in CI.

### Changed

- 2026-07-21 — All example template URLs consolidated onto a single host: `https://example.com/templates/...` replaces the `templates.example.com` subdomain throughout the specification and examples. Template URLs are identifiers first; a dedicated template host in every example suggested a deployment choice (a separate template server) that the protocol does not make.
- 2026-07-21 — JSON Schemas upgraded from draft-07 to the [JSON Schema 2020-12](https://json-schema.org/specification-links#2020-12) dialect (`$schema` is now `https://json-schema.org/draft/2020-12/schema`). The schemas already used the post-draft-07 `$defs` keyword, so the declared dialect now matches the keywords in use; no other schema changes were needed. CI and local validation pass `--spec=draft2020` to ajv. The archived RVST schemas remain draft-07.
- 2026-07-20 — Optional template metadata on view descriptors (new Section 3.6): an advisory `type` member (media type hint for the template resource) and an `integrity` member (W3C Subresource Integrity); an integrity mismatch is treated as a template fetch failure.
- 2026-07-20 — Descriptor references (new Section 3.7): a slot value may be `{"descriptor": <url>}` pointing at a standalone view descriptor resource, enabling shared, independently cacheable subtrees; resolution, cycle, and failure rules added to Sections 8–10, and the schema gained `SlotDescriptor`/`DescriptorReference` definitions.
- 2026-07-20 — New Conformance section (15) defining the VDP Server, VDP Client, and VDP BFF conformance classes; RFC 2119/RFC 8174 requirement keywords adopted in Section 2.
- 2026-07-20 — `VDP-Version` may appear on any response carrying a view descriptor and on descriptor resources, not only on `OPTIONS`; its value must match the media type `version` parameter, which wins on disagreement (Section 13.1).
- 2026-07-20 — Noted that the OData `View` annotation alias is provisional until a formal OData vocabulary is published; strict-conformance deployments should prefer the `Link` header transport (Section 4.3).
- 2026-07-20 — Discovery document standardization: the document is served as `application/vdp-discovery+json` (new Section 12.3, RFC 6839 `+json` suffix) and MUST NOT be served as `application/vdp+json`; the `vdp` well-known URI suffix gets an IANA Considerations entry (Section 12.4, RFC 8615); the Section 12 preamble notes no registrations have been submitted yet; a discovery extensibility clause requires clients to ignore unrecognized members; `endpoints` is documented as aligned in spirit with RFC 9264 (Linkset).
- 2026-07-20 — Template allowlist (Section 10) now defines its source chain: local client configuration, then the discovery document's `trustedTemplateUrls`, then a same-origin default — so the validation requirement no longer depends on the optional discovery document.
- 2026-07-20 — New Section 12.5 lists the `View-Template`, `VDP-Support`, `VDP-Version`, and `VDP-Platform` HTTP fields for registration in the RFC 9110 field name registry; `X-VDP-Platform` renamed to `VDP-Platform` (the `X-` prefix is deprecated by RFC 6648); `VDP-Version` alone now suffices to signal VDP support (Section 13.1).
- 2026-07-20 — Section 4.4: servers MUST NOT emit more than one `Link` header value with `rel="view-descriptor"`; clients receiving multiple use the first in field order.
- 2026-07-20 — Discovery `endpoints` keys may be RFC 6570 Level 1 URI Templates (each expression matches one path segment; literal entries take precedence); keys are interpreted relative to the origin serving the discovery document; `descriptor` values may be relative references resolved against the discovery document URL; caching guidance added (Section 13.2).
- 2026-07-20 — The `DiscoveryDocument` definition moved out of `vdp.v0-1.schema.json` into the new dedicated `vdp-discovery.v0-1.schema.json`; discovery examples are now validated in CI.
- 2026-07-19 — The RVST-era documentation moved under `docs/archive/` with an archived-content notice on each document, and the cross-platform support diagram was redrawn with a VDP `_view` payload.
- 2026-07-19 — Discovery document `endpoints` entries now use a `descriptor` field holding the URL of the endpoint's view descriptor resource; the field was previously named `template` although it never held a template URL. The schema's `DiscoveryDocument` definition was updated to match.
- 2026-07-19 — Schema `$id` and `$ref` examples moved from `vdp.dev` to `https://vdprotocol.org/schemas/vdp.v0-1.schema.json`.
- 2026-07-19 — Corrected the relative URL resolution example (Section 5.4): per RFC 3986, references without a leading slash resolve under the base URL's path; the example now uses root-relative paths and notes the distinction.
- 2026-07-19 — Clarified `OPTIONS` discovery (Section 13.1): support is advertised with the `VDP-Support` and `VDP-Version` response headers.
- 2026-07-19 — Editorial clarity pass: rewrote the Static/Dynamic Composition definitions, explained descriptor recursion in the abstract, made the problem statement concrete, and assorted sentence-level fixes.
- 2026-07-18 — Template URLs in examples no longer carry `.html` extensions; templates are format-neutral resources.

### Deprecated

- RVST (Representational View State Transfer), VDP's predecessor, is archived in this repository: schemas under `schemas/`, examples under `examples/example-*.json`, the unfinished HAL variant draft as `examples/rvst-hal-draft.json`, and documentation under `docs/archive/`. The VDP specification supersedes RVST.

*[VDP]: View Descriptor Protocol
*[HAL]: Hypertext Application Language
