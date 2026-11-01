# Changelog

## Unreleased

Initial release.

- Parse and validate international phone numbers against embedded regional rules.
- Normalize international and country-hinted national input to E.164.
- Parse national input with `parse_with_country` and return owned normalized
  strings or extracted spans through convenience functions.
- Look up countries and calling codes, with ambiguity reporting for shared ranges.
- Format numbers and extract international number spans from text.
- Name ungrouped national formatting `NationalDigits`, retaining `National`
  for compatibility, and reject malformed parsed models before formatting.
- Include pinned metadata, source provenance, and reference-based tests.

See the README for supported input formats and current limitations.
