# Changelog

All notable changes to the View Descriptor Protocol (VDP) specification are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The specification is in early working draft; entries below track the evolution of the draft.

## [Unreleased]

## [0.2.0-alpha] — 2026-08-03

Second tagged release of the working draft: the protocol version moves to 0.2, adding one member — `transform` — plus its supporting rules.

### Added

- 2026-08-03 — **The `transform` member** (new Section 3.8): an optional, declarative mapping on any view descriptor node that adapts the API response representation into the JSON model the node's template expects. Nine grammar productions over [RFC 6901](https://www.rfc-editor.org/rfc/rfc6901) JSON Pointers — Pointer, Mapping, List, `$map`/`$to` projection, `$entries`, `$get`/`$default`, `$count`, `$merge`, and the `$mapper` escape hatch referencing client-registered mapping code (an identifier matched verbatim, never fetched). Every node's transform is evaluated against the original response representation, never an ancestor's output (independent projection); no transform means the template receives the representation unchanged; when a transform is present the template receives exactly its result. Inline transform support is REQUIRED for client conformance, `$mapper` support OPTIONAL. The formal grammar moved to Section 3.9 and covers the transform productions; Section 3.7 now recommends that referenced descriptors stay transform-free. **Note:** earlier design discussion used `"transform": "<string>"` to mean a jq expression. In the final design a string is an RFC 6901 JSON Pointer and an object is a mapping — same syntax, different semantics.
- 2026-08-03 — **Extensibility rule** (new Section 3.10): clients MUST reject a view descriptor node containing an unrecognized member unless its name begins with `x-`. Spec-defined members are must-understand; vendor extensions use the `x-` prefix. (The discovery document keeps its opposite, ignore-unknown clause.)
- 2026-08-03 — **Transform failure handling** (new Section 9.6): malformed transforms (unknown `$` construct, invalid pointer syntax) invalidate the descriptor per Section 9.3; missing pointers and wrong-type `$map`/`$entries`/`$count` targets yield `null` and are not errors; an unrecognized `$mapper` URI or a failing slot-node transform is a slot failure per Section 9.1. Section 9.4 rule 2 amended: when a declared root transform fails, the client MUST NOT fall back to rendering the template against untransformed input — error template only.
- 2026-08-03 — **Discovery `mappers` member** (Section 13.2): a discovery document SHOULD list the `$mapper` URIs its descriptors may reference, so clients can check their registered mappers up front.
- 2026-08-03 — **v0.2 JSON Schemas** (`vdp.v0-2.schema.json`, `vdp-discovery.v0-2.schema.json`): transform grammar validated with key-presence `if`/`then`/`else` discrimination, the Section 3.10 extensibility rule enforced via `unevaluatedProperties`/`patternProperties`, and the discovery `mappers` member. The v0-1 schemas remain published at their `$id` URLs.
- 2026-08-03 — **Language-neutral test corpus** (`tests/`): descriptor fixtures with expected accept/reject, transform triples (`input.json` + `transform.json` + `expected.json`), rendering fixtures for independent projection and embedded-transport stripping, and a dependency-free Node reference runner (`tests/run-transforms.mjs`), all validated in CI.

### Changed

- 2026-08-03 — Protocol version bumped **0.1 → 0.2**. Terminology now defines a template as a renderable unit whose URI implies a fixed data contract. Section 4.2 strips `_view`/`_views` from the transform input; Section 4.4 makes discovery a prefetch hint with the response descriptor authoritative; the Section 6.1 Qute row moved from context-inheriting `{#insert}` to explicitly parameterised `{#include}`; Section 8 step 6 is now per-node rendering; the Section 7 examples show per-node transforms. Design Decision #3 rewritten: data-to-template mapping is now in scope as declarative reshaping only (jq, JMESPath, a custom expression language, and a root-only transform were considered and rejected); Design Decision #2 explains why transforms are not template parameters and why there is no `$const`.

- 2026-07-29 — New Section 9.5 (Server Error Responses): servers SHOULD report errors on view descriptor resources and discovery documents as [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) problem details (`application/problem+json`); client-side handling in Sections 9.1–9.4 is unchanged. A corresponding row was added to the Section 11 standards table.
- 2026-07-29 — New Section 16 (References): a table of every RFC the specification relies on, with the sections that use each, and a second table of the non-RFC standards cited (W3C Subresource Integrity, JSON Schema 2020-12, HAL, OData 4.0, OpenAPI). Citations added where standards were used but uncited: RFC 8259 (JSON) in Section 2 and RFC 9111 (HTTP Caching) in Section 5.2.

## [0.1.0-alpha] — 2026-07-28

First tagged release of the working draft.

### Added

- VDP specification (`view-descriptor-protocol.md`): view descriptor format with recursive slots, slot arrays, multiple named views, transport via inline `_view`/`_views` or HTTP `Link` headers (`rel="view-descriptor"`) and the `View-Template` shorthand, OData4 instance annotations, caching and versioning of descriptor resources, client resolution algorithm, error handling, security considerations, discovery (`OPTIONS` headers, `/.well-known/vdp`, OpenAPI `x-vdp` extension), and partial update patterns.
- JSON Schemas (2020-12 dialect): `vdp.v0-1.schema.json` validating `ViewDescriptor` and `MultiViewDescriptor` payloads, and `vdp-discovery.v0-1.schema.json` validating the `/.well-known/vdp` discovery document.
- Canonical examples (`examples/vdp-*.json`, `examples/discovery-*.json`), validated against the schemas in CI.

### Changed

- 2026-07-24 — Template identifiers are now URI-references: the schema's `template` and discovery `trustedTemplateUrls` values changed from `format: uri` to `format: uri-reference`, and the `$defs` type was renamed `TemplateURL` → `TemplateURI`. Section 5.4 defines three identifier forms — absolute URI, RFC 3986 relative reference, and scheme-less opaque identifier (e.g. `example.com/templates/card`, host-qualified, NOT resolved as a relative reference) — with the HTTPS requirement scoped to network retrieval. "Template URL" renamed to "template URI" throughout the specification, and the example template values and discovery allowlist are now scheme-less.
- 2026-07-21 — New Section 6.3 (Template Sources) makes explicit that a template URL is an identifier first and a fetchable location only secondarily: clients MAY satisfy template URLs from any source — an application bundle, templates shipped with the page, a BFF-local store or template service, or a network fetch — all equally conforming, with the absolute URL (Section 5.4) as the template's identity and cache key. The Section 2 Template URL definition, Section 8 algorithm ("obtain" rather than "fetch" templates), Section 10 (its requirements now explicitly scoped to network retrieval), Section 15.2 client conformance, and the schema's TemplateURL description were aligned accordingly.
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

[Unreleased]: https://github.com/ViewDescriptorProtocol/VDP/compare/v0.2.0-alpha...HEAD
[0.2.0-alpha]: https://github.com/ViewDescriptorProtocol/VDP/releases/tag/v0.2.0-alpha
[0.1.0-alpha]: https://github.com/ViewDescriptorProtocol/VDP/releases/tag/v0.1.0-alpha

*[VDP]: View Descriptor Protocol
*[HAL]: Hypertext Application Language
