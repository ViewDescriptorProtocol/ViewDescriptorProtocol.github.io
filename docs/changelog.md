# Changelog

All notable changes to the View Descriptor Protocol (VDP) specification are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The specification is in early working draft; entries below track changes to the v0.1 draft until its first tagged release.

## [0.1.0] — Working Draft (unreleased)

### Added

- VDP specification (`view-descriptor-protocol.md`): view descriptor format with recursive slots, slot arrays, multiple named views, transport via inline `_view`/`_views` or HTTP `Link` headers (`rel="view-descriptor"`) and the `View-Template` shorthand, OData4 instance annotations, caching and versioning of descriptor resources, client resolution algorithm, error handling, security considerations, discovery (`OPTIONS` headers, `/.well-known/vdp`, OpenAPI `x-vdp` extension), and partial update patterns.
- JSON Schema `vdp.v0-1.schema.json` (draft-07) validating `ViewDescriptor` and `MultiViewDescriptor` payloads, with a `DiscoveryDocument` definition for `/.well-known/vdp`.
- Canonical examples (`examples/vdp-*.json`), validated against the schema in CI.

### Changed

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
*[RVST]: Representational View State Transfer
