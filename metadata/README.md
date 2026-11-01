# Numbering metadata

The runtime rules come from Google libphonenumber commit
`1ae0d623301b302f828628dfc368c983e8d27141`. The unmodified XML and its SHA-256
are in `libphonenumber/`. The [Apache-2.0 license](../LICENSE.libphonenumber)
applies to this data and its derived tables. No data is fetched at runtime.

Country names and territory-prefix conventions originated in Rust phonelib.
The table includes Tristan da Cunha (`TA`). South Georgia (`GS`) remains
available for lookup with a zero length mask because the reference supplies
no numbering plan for it.

## Runtime files

- `regions.tsv`: 259 lookup entries, including repeated territory prefixes
  and nine global services.
- `numbering_plans.tsv`: 254 plans; tab-separated ISO code, calling code,
  length bitmask, DFA byte offset, national-prefix parsing regex,
  captured-digit transformation, and primary-region flag.
- `numbering_rules.bin`: decimal DFAs, 22 bytes per state. Each state contains
  eleven little-endian u16 values: an accepting flag and transitions for
  digits 0 through 9. State 0 is initial; 65535 is a dead transition. State
  indices are relative to the plan's byte offset.

The DFAs encode the intersection of each region's general pattern and its
supported number-type patterns and lengths. All three files are embedded at
compile time; validation performs one transition per national digit.

## Reference fixtures

Tests retain 1,143 upstream examples, 720 national-prefix examples, and 12,099
validity fixtures. Expected validity was checked against the source regular
expressions independently of the compiled DFA. Shared calling codes are
accepted when at least one region matches. The library's 15-digit E.164 limit
also applies to the fixtures.

## Updating

Generation tooling is not part of this repository. A metadata update must
regenerate the runtime tables and reference fixtures together from an explicit
upstream commit. Update `libphonenumber/source.json` with the commit and XML
checksum, review all resulting changes, and run the full Goose test suite.
New or removed regions require an explicit table review. Keep the hand-written
normalization and validation regressions intact.
