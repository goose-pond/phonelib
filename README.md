# phonelib

Phone-number parsing, validation, and E.164 normalization for Goose.
Numbering rules are embedded in the program. There are no runtime downloads,
data files to deploy, or native dependencies beyond Goose's standard library.

## Use

Requires [Goose v2026.3](https://github.com/aardappel/goose/releases/tag/v2026.3).
The import below targets the planned `v0.1.0` release. Until it is published,
use the local-checkout import described below. Declare the package in your
program's root file:

```goose
import phonelib from "goose-pond/phonelib@v0.1.0";

fn main() {
    var number: u8[>..] = [];
    if phonelib::normalize_with_country("020 7946 0958", "GB", number) {
        print(number); // +442079460958
    }

    let country, found = phonelib::country_from_phone_number("+15062345678");
    if found { print(country.code); } // CA
}
```

Run it with `goose run main.goose`. Goose fetches the pinned package on first
use. For a local checkout, use `import phonelib from "path/to/phonelib";` with
an absolute path or a relative path beginning with `./` or `../`.

## Behavior

- **Validate:** `is_valid_phone_number` checks the calling code, lengths, and
  regional number patterns. `is_possible_phone_number` checks lengths only.
- **Normalize:** international input keeps every digit. National input uses
  a country hint and that country's prefix rules. Significant leading zeros,
  including Italy's, are preserved.
- **Identify:** country lookup uses regional patterns. Shared ranges, such
  as NANP toll-free numbers, can remain ambiguous.
- **Format:** E.164, a simple international format, national significant
  digits, or an RFC 3966 `tel:` URI.
- **Extract:** find numbers beginning with `+` or `00`, returned as UTF-8 byte
  offsets into the original text.

Output functions append to caller-owned buffers. Invalid input leaves the
buffer unchanged. Functions that return a success flag also return an empty
result on failure.

See the [API reference](docs/api.md) for signatures, examples, and input rules.

## Scope

The library accepts ASCII digits and common phone-number separators, with a
maximum of 15 E.164 digits. It does not parse extensions, vanity numbers, or
short codes. Formatting is intentionally minimal; it does not reproduce each
country's preferred grouping.

`00` is accepted as international notation, independently of a country hint.
The library does not interpret every country's international dialing prefix.
International numbers containing a national trunk prefix, such as
`+44 (0)20 ...`, must be corrected or supplied in national format with a hint.

Validity means a number matches the bundled numbering-plan snapshot. It does
not establish that the number is assigned, reachable, or owned by a user.

## Test

The quick suite needs only Goose:

```text
goose run tests/phonelib_test.goose --debug --no-bce
```

To check optimized and native builds, use a C compiler discoverable by
`goose toolchain`:

```text
goose run tests/phonelib_test.goose -O2
goose build tests/phonelib_test.goose --debug --no-bce -o build/test-debug
goose build tests/phonelib_test.goose -O2 -o build/test-release
./build/test-debug
./build/test-release
```

CI runs one Linux job: it verifies the metadata source checksum, runs the example
and checked tests, and builds and runs an optimized native executable from outside
the checkout. Tests cover 1,143 upstream examples, 720 national-prefix
cases, 12,099 validity fixtures, and regressions for normalization and extraction.

Run `goose run examples/basic.goose` for a local example.

## Metadata and license

Numbering rules come from a pinned Google libphonenumber snapshot. The source
XML and checksum are included; see [metadata maintenance](metadata/README.md).

The library code is [MIT-licensed](LICENSE). The numbering metadata is licensed
under Apache-2.0. Country names and territory-prefix conventions were adapted
from Rust phonelib. Full attributions and licenses are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
