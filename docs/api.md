# API reference

All names below are in the `phonelib` namespace. Strings are `const u8[:]`
views; output buffers are caller-owned `u8[>..]` arrays passed by reference.

## Parse and validate

```goose
fn parse_phone_number(text: const u8[:]) -> PhoneNumber, bool
fn is_valid_phone_number(text: const u8[:]) -> bool
fn is_possible_phone_number(text: const u8[:]) -> bool
```

`parse_phone_number` and `is_valid_phone_number` check the calling code,
national-number lengths, and regional patterns in the embedded metadata.
`is_possible_phone_number` checks the calling code and lengths only. It can
return true for an invalid prefix, such as `+440000000000`.

International input starts with `+` or `00`. For compatibility with common
NANP input, an unprefixed number beginning with calling code `1` is also
accepted. Use `normalize_with_country` for national input.

ASCII spaces, tabs, line breaks, hyphens, dots, slashes, and parentheses are
ignored. Only ASCII digits are supported; letters and extension markers are
rejected. After removing international notation and separators, the number
must fit within 15 digits. International parsing does not remove national
prefixes or rewrite digits.

On failure, parsing returns an empty `PhoneNumber` and `false`.

```goose
struct PhoneNumber {
    digits: u8[15],
    digit_count: i64,
    calling_code_length: i64,
    country: Country,
    country_is_ambiguous: bool,
}
```

`digits[..digit_count]` contains E.164 digits without `+`.
`calling_code_length` counts the actual calling code, so it is `1` for all
NANP numbers, including territories with a longer `Country.e164_prefix`.

## Normalize

```goose
fn normalize_phone_number(text: const u8[:], out: u8[>..]&) -> bool
fn normalized_phone_number(text: const u8[:]) -> u8[>..], bool
fn normalize_with_country(text: const u8[:], iso_code: const u8[:], out: u8[>..]&) -> bool
```

Successful normalization produces `+` followed by the E.164 digits.
Buffer-taking functions append their result. Failure leaves the buffer
unchanged; `normalized_phone_number` instead returns an empty array and `false`.

`normalize_with_country` accepts an uppercase regional code such as `GB`,
`LB`, or `US`. A valid national significant number is preserved. Otherwise,
the region's national-prefix parsing and transformation rules are applied and
the result is validated. Italy's significant leading zero is retained.

| Input | Country hint | Output |
| --- | --- | --- |
| `020 7946 0958` | `GB` | `+442079460958` |
| `01123456` | `LB` | `+9611123456` |
| `12015550123` | `US` | `+12015550123` |
| `0212345678` | `IT` | `+390212345678` |
| `011 15 2345 6789` | `AR` | `+5491123456789` |

An explicit `+` or `00` takes precedence over the country hint, even if that
hint is unknown. `00` is treated as international notation, rather than as a
country-specific dialing instruction.

For NANP territories, seven-digit local numbers use the first listed territory
prefix. Full national numbers can specify another valid area code. For example,
the Dominican Republic's default prefix is `1809`; a ten-digit national number
beginning with `829` retains that area code.

## Countries and calling codes

```goose
fn country_from_phone_number(text: const u8[:]) -> Country, bool
fn calling_code_from_phone_number(text: const u8[:]) -> i64, bool
fn phone_number_country_is_ambiguous(text: const u8[:]) -> bool
fn country_by_iso_code(code: const u8[:]) -> Country, bool
fn countries_by_iso_code(code: const u8[:], out: Country[>..]&) -> i64
fn countries_by_calling_code(code: i64, out: Country[>..]&) -> i64
fn country_at(index: i64) -> Country
fn country_count() -> i64
fn append_countries(out: Country[>..]&) -> i64
```

Lookup by number requires a valid parsed number. Regional patterns distinguish
many shared-code regions, including US and Canadian area codes. If several
regions match, the upstream primary region is preferred when present;
otherwise the first matching table entry is returned. Check
`phone_number_country_is_ambiguous` before treating that choice as definitive.
It returns false for invalid input.

```goose
struct Country {
    name: const u8[:],
    code: const u8[:],
    calling_code: i64,
    e164_prefix: i64,
    length_mask: i64,
    global_service: bool,
}
```

`calling_code` is the international calling code. `e164_prefix` also includes
the area code for NANP territory entries; Antigua and Barbuda, for example,
uses calling code `1` and prefix `1268`. A set bit `n` in `length_mask` denotes
an accepted length of `n` digits after `e164_prefix`. This mask is a length
summary, not a substitute for full validation.

Country strings reference embedded data and remain valid for the program's
lifetime. ISO lookup is case-sensitive and excludes the special `001` global
service entries. Singular ISO lookup returns the first match; plural lookup
returns all prefixes for that region.

The table has 259 rows, not 259 distinct countries: some territories have
multiple prefixes, and nine rows represent global services. The legacy `GS`
entry remains available for lookup with a zero length mask because the
reference metadata supplies no numbering plan for it.

Array-taking functions append and return the number of entries added.
Out-of-range `country_at` calls return an empty country. Failed singular
lookups return an empty country or zero calling code, together with `false`.

## Format

```goose
enum PhoneFormat { E164, International, National, RFC3966 }

fn format_phone_number(text: const u8[:], format: PhoneFormat, out: u8[>..]&) -> bool
fn format_parsed_phone_number(number: PhoneNumber, format: PhoneFormat, out: u8[>..]&)
```

For `+12684641234`:

| Format | Output |
| --- | --- |
| `E164` | `+12684641234` |
| `International` | `+1 2684641234` |
| `National` | `2684641234` |
| `RFC3966` | `tel:+12684641234` |

`National` means the ungrouped national significant number, including a NANP
area code. It does not add a trunk prefix. `International` adds one space
after the calling code; neither format implements national grouping rules.

Both functions append. `format_phone_number` returns false without changing
the output if parsing fails. Pass only an unchanged result from a successful
parse to `format_parsed_phone_number`; it does not revalidate model fields.

## Extract from text

```goose
struct PhoneSpan { start: i64, end: i64 }

fn extract_phone_numbers_from_text(text: const u8[:], out: PhoneSpan[>..]&) -> i64
```

Appends valid international candidates beginning with `+` or `00`, returning
the number of spans added. Each span is a half-open UTF-8 byte range:
`text[span.start..span.end]` is the original candidate, including internal
separators but excluding trailing punctuation.

Candidates attached directly to ASCII letters, digits, or underscores are
rejected. This is an ASCII boundary rule, not Unicode word segmentation.
National-format numbers require a country hint and are not extracted.

## Verification limits

The bundled rules describe supported numbering ranges at a pinned snapshot.
A valid result does not confirm subscriber assignment, reachability, or
ownership. Use an appropriate verification step when those properties matter.
