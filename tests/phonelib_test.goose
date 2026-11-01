import phonelib from "..";

var checks = 0;
var failures = 0;

fn expect(condition: bool, label: const u8[:]) {
    checks++;
    if !condition { failures++; print("FAIL: ", label); }
}

fn normalized(input: const u8[:], expected: const u8[:]) {
    var out: u8[>..] = [];
    let ok = phonelib::normalize_phone_number(input, out);
    expect(ok && out == expected, input);
    if !ok || out != expected { print("  expected ", expected, ", got ", out); }
}

fn national(input: const u8[:], region: const u8[:], expected: const u8[:]) {
    var out: u8[>..] = [];
    let ok = phonelib::normalize_with_country(input, region, out);
    expect(ok && out == expected, input);
    if !ok || out != expected { print("  region ", region, ": expected ", expected, ", got ", out); }
}

fn invalid(input: const u8[:]) {
    var out: u8[>..] = [];
    out.append("keep:");
    expect(!phonelib::normalize_phone_number(input, out), input);
    expect(out == "keep:", "invalid normalization leaves output untouched");
    let number, ok = phonelib::parse_phone_number(input);
    expect(!ok && number.digit_count == 0, "invalid parse returns empty result");
}

fn formatted(input: const u8[:], kind: phonelib::PhoneFormat, expected: const u8[:]) {
    var out: u8[>..] = [];
    out.append("keep:");
    let ok = phonelib::format_phone_number(input, kind, out);
    expect(ok && out[5..] == expected && out[..5] == "keep:", "format appends expected output");
}

fn extraction(text: const u8[:], first: const u8[:], second: const u8[:]) {
    var spans: phonelib::PhoneSpan[>..] = [];
    spans.push(phonelib::PhoneSpan { start: 0, end: 0 });
    let expected = if second.len > 0 { 2 } else { if first.len > 0 { 1 } else { 0 } };
    let added = phonelib::extract_phone_numbers_from_text(text, spans);
    expect(added == expected && spans.len == expected + 1, text);
    expect(spans[0].start == 0 && spans[0].end == 0, "extraction preserves existing spans");
    if added != expected { print("  expected ", expected, " spans, got ", added); return; }
    if expected > 0 { expect(text[spans[1].start..spans[1].end] == first, "first span byte offsets"); }
    if expected > 1 { expect(text[spans[2].start..spans[2].end] == second, "second span byte offsets"); }
}

fn test_metadata() {
    expect(phonelib::country_count() == 259, "259 lookup entries including Tristan da Cunha");
    expect(phonelib::country_at(-1).code == "", "negative country index");
    expect(phonelib::country_at(259).code == "", "past-end country index");
    var all: phonelib::Country[>..] = [];
    all.push(phonelib::country_at(0));
    expect(phonelib::append_countries(all) == 259 && all.len == 260, "append all countries");
    var services = 0;
    for i in phonelib::country_count() {
        let country = phonelib::country_at(i);
        expect(country.name.len > 0 && country.code.len > 0 && country.calling_code > 0 &&
               (country.length_mask > 0 || country.code == "GS"), "metadata row is complete");
        expect(all[i + 1].code == country.code && all[i + 1].e164_prefix == country.e164_prefix,
               "indexed metadata matches append order");
        if country.global_service { services++; } else {
            let found, ok = phonelib::country_by_iso_code(country.code);
            expect(ok && found.name == country.name && found.calling_code == country.calling_code,
                   "every regional ISO code round trips");
            var variants: phonelib::Country[>..] = [];
            let variant_count = phonelib::countries_by_iso_code(country.code, variants);
            var prefix_found = false;
            for variant in variants {
                if variant.e164_prefix == country.e164_prefix { prefix_found = true; }
            }
            expect(variant_count == variants.len && prefix_found, "plural ISO lookup includes every prefix");
        }
    }
    expect(services == 9, "nine global service entries");
    let missing, missing_ok = phonelib::country_by_iso_code("ZZ");
    expect(!missing_ok && missing.code == "", "unknown ISO code");
    let service, service_ok = phonelib::country_by_iso_code("001");
    expect(!service_ok, "global services are excluded from ISO lookup");
    var nanp: phonelib::Country[>..] = [];
    let nanp_count = phonelib::countries_by_calling_code(1, nanp);
    expect(nanp_count > 2 && nanp_count == nanp.len, "shared calling code lookup");
    for country in nanp { expect(country.calling_code == 1, "NANP uses calling code 1"); }
    expect(phonelib::countries_by_calling_code(999, nanp) == 0 && nanp.len == nanp_count,
           "missing calling code leaves array untouched");
    var iso: phonelib::Country[>..] = [];
    expect(phonelib::countries_by_iso_code("GB", iso) == 1, "plural ISO lookup");
    expect(iso.len == 1 && iso[0].calling_code == 44, "GB calling code");
    expect(phonelib::countries_by_iso_code("001", iso) == 0 && iso.len == 1,
           "plural ISO excludes global services");
}

fn test_parsing() {
    normalized("+1 (202) 555-0173", "+12025550173");
    normalized("  +44 20 7946 0958  ", "+442079460958");
    normalized("00442079460958", "+442079460958");
    normalized("12025550173", "+12025550173");
    normalized("+1 268 464 1234", "+12684641234");
    normalized("+961 1 234 567", "+9611234567");
    normalized("+80012345678", "+80012345678");
    normalized("+878101234567890", "+878101234567890");
    national("2025550173", "US", "+12025550173");
    national("02079460958", "GB", "+442079460958");
    national("0612345678", "IT", "+390612345678");
    national("8 (912) 345-67-89", "RU", "+79123456789");
    national("06 1 234 5678", "HU", "+3612345678");
    national("4641234", "AG", "+12684641234");
    national("+442079460958", "US", "+442079460958");
    national("00442079460958", "ZZ", "+442079460958");
    invalid(""); invalid("+"); invalid("00"); invalid("abc"); invalid("++12025550173");
    invalid("+1+2025550173"); invalid("+999123456789"); invalid("+1202555017");
    invalid("+120255501733"); invalid("+11225550173"); invalid("+12115550173");
    invalid("+12021550173"); invalid("+12681641234"); invalid("+8781234567890123");
    invalid("+12025550173x123"); invalid("+12025550173abc"); invalid("442079460958");
    invalid("+123456789012345678901234567890");
    var untouched: u8[>..] = [];
    untouched.append("keep");
    expect(!phonelib::normalize_with_country("2025550173", "ZZ", untouched) && untouched == "keep",
           "unknown country fails without modifying output");
    expect(!phonelib::normalize_with_country("123", "US", untouched) && untouched == "keep",
           "invalid national number leaves output untouched");
    let country, ok = phonelib::country_from_phone_number("+442079460958");
    expect(ok && country.code == "GB", "UK country lookup");
    let code, code_ok = phonelib::calling_code_from_phone_number("+12684641234");
    expect(code_ok && code == 1, "territory calling code excludes area code");
    expect(!phonelib::phone_number_country_is_ambiguous("+12025550173"), "area-code rules identify US");
    expect(phonelib::phone_number_country_is_ambiguous("+18002345678"), "shared toll-free country ambiguity");
    expect(!phonelib::phone_number_country_is_ambiguous("+9611234567"), "unshared calling code");
    let owned, owned_ok = phonelib::normalized_phone_number("+1 (202) 555-0173");
    expect(owned_ok && owned == "+12025550173", "owned normalization result");
    let empty, empty_ok = phonelib::normalized_phone_number("bad");
    expect(!empty_ok && empty.len == 0, "owned invalid normalization result");
    formatted("+12684641234", phonelib::PhoneFormat.E164, "+12684641234");
    formatted("+12684641234", phonelib::PhoneFormat.International, "+1 2684641234");
    formatted("+12684641234", phonelib::PhoneFormat.National, "2684641234");
    formatted("+12684641234", phonelib::PhoneFormat.RFC3966, "tel:+12684641234");
}

fn test_extraction() {
    extraction("Call +1 202-555-0173 or +44 20 7946 0958.", "+1 202-555-0173", "+44 20 7946 0958");
    extraction("Call +12025550173, +442079460958!", "+12025550173", "+442079460958");
    extraction("Call 00442079460958.", "00442079460958", "");
    extraction("Call +12025550173 +442079460958", "+12025550173", "+442079460958");
    extraction("Call +12025550173\n+442079460958", "+12025550173", "+442079460958");
    extraction("☎ +9611234567!", "+9611234567", "");
    extraction("No phone number here.", "", "");
    extraction("id+12025550173", "", "");
    // Extraction promises internationally prefixed candidates and word boundaries.
    extraction("id 12025550173", "", "");
    extraction("+12025550173abc", "", "");
    extraction("+12025550173_ext", "", "");
    extraction("++12025550173", "", "");
    extraction("+12025550173 00442079460958", "+12025550173", "00442079460958");
    extraction("00442079460958 0012025550173", "00442079460958", "0012025550173");
    extraction("+999123456 +442079460958", "+442079460958", "");
    extraction("+123456789012345678901234567890, +442079460958", "+442079460958", "");
    extraction("+878101234567890", "+878101234567890", "");
    extraction("00878101234567890", "00878101234567890", "");
    var long_text: u8[>..] = [];
    long_text.push('+');
    for i in 100000 { long_text.push('2'); }
    long_text.append(", +442079460958");
    var spans: phonelib::PhoneSpan[>..] = [];
    expect(phonelib::extract_phone_numbers_from_text(long_text, spans) == 1,
           "long invalid candidate does not hide next valid number");
    expect(spans.len == 1 && spans[0].start == 100003 && spans[0].end == long_text.len,
           "long-input span offsets");
}

// These are structural fixtures, not assertions that synthetic numbers are assigned.
fn test_metadata_lengths() {
    for i in phonelib::country_count() {
        let country = phonelib::country_at(i);
        for length in 1..16 {
            if (country.length_mask & (1 << length)) == 0 { continue; }
            var input: u8[>..] = [];
            format(input, "+", country.e164_prefix);
            for digit in length { input.push('2'); }
            if input.len > 16 {
                expect(!phonelib::is_valid_phone_number(input), "E.164 total length overrides metadata");
                continue;
            }
            expect(phonelib::is_possible_phone_number(input), "every supported length is possible");
        }
    }
}

fn test_generated_inputs() {
    let alphabet = "0123456789+ -.()/abc_\t\n";
    var state = 1729;
    for sample in 1000 {
        var input: u8[>..] = [];
        for i in sample % 65 {
            state = (state * 48271) % 2147483647;
            input.push(alphabet[state % alphabet.len]);
        }
        var out: u8[>..] = [];
        out.append("keep:");
        let ok = phonelib::normalize_phone_number(input, out);
        if ok {
            var again: u8[>..] = [];
            expect(phonelib::normalize_phone_number(out[5..], again) && again == out[5..],
                   "generated normalization is idempotent");
        } else { expect(out == "keep:", "generated invalid input leaves output untouched"); }
        var spans: phonelib::PhoneSpan[>..] = [];
        let added = phonelib::extract_phone_numbers_from_text(input, spans);
        expect(added == spans.len, "generated extraction count");
        var previous_end = 0;
        for span in spans {
            expect(span.start >= previous_end && span.end <= input.len && span.end > span.start,
                   "generated spans are ordered and in bounds");
            expect(phonelib::is_valid_phone_number(input[span.start..span.end]), "generated spans parse");
            previous_end = span.end;
        }
    }
}

fn test_release_regressions() {
    // Digit preservation, national prefixes, and shared calling-code regressions.
    normalized("+3758011234567", "+3758011234567");
    national("030123456", "DE", "+4930123456");
    national("01123456", "LB", "+9611123456");
    national("12015550123", "US", "+12015550123");
    national("0212345678", "IT", "+390212345678");
    national("8 801 1234567", "BY", "+3758011234567");
    national("1 268 4641234", "AG", "+12684641234");
    national("2684641234", "AG", "+12684641234");
    national("8292345678", "DO", "+18292345678");
    national("011 15 2345 6789", "AR", "+5491123456789");
    national("021 11 2345 6789", "BR", "+551123456789");
    invalid("+375011234567");
    invalid("+440000000000");
    invalid("+878123456789012");
    invalid("+49030123456");
    invalid("+96101123456");
    invalid("+44 (0)20 7946 0958");
    expect(phonelib::is_possible_phone_number("+440000000000"), "possible is distinct from valid");
    expect(!phonelib::is_possible_phone_number("+9991234567"), "unknown calling code is impossible");
    let canada, found = phonelib::country_from_phone_number("+15062345678");
    expect(found && canada.code == "CA", "Canadian area code identifies Canada");
    expect(!phonelib::phone_number_country_is_ambiguous("+15062345678"), "Canadian example unambiguous");
    let ta, ta_ok = phonelib::country_by_iso_code("TA");
    expect(ta_ok && ta.calling_code == 290, "Tristan da Cunha metadata is available");
    let gs, gs_ok = phonelib::country_by_iso_code("GS");
    expect(gs_ok && gs.length_mask == 0, "South Georgia is lookup-only without a reference plan");
}

// Frozen upstream examples and independently checked validity expectations.
// See metadata/libphonenumber/source.json for provenance.
const REFERENCE_EXAMPLES = embed_file("reference_examples.tsv");
const REFERENCE_VALIDATION = embed_file("reference_validation.tsv");
const REFERENCE_NATIONAL = embed_file("reference_national.tsv");

fn test_reference_national() {
    var pos = 0;
    while pos < REFERENCE_NATIONAL.len {
        let row, next = phonelib::data_row(REFERENCE_NATIONAL, pos);
        national(phonelib::field(row, 1), phonelib::field(row, 0), phonelib::field(row, 2));
        pos = next;
    }
}

fn test_reference_examples() {
    var pos = 0;
    var count = 0;
    while pos < REFERENCE_EXAMPLES.len {
        let row, next = phonelib::data_row(REFERENCE_EXAMPLES, pos);
        let iso = phonelib::field(row, 0);
        let input = phonelib::field(row, 2);
        normalized(input, input);
        expect(phonelib::is_valid_phone_number(input), "upstream example validates");
        let code, code_ok = phonelib::calling_code_from_phone_number(input);
        if iso != "001" && code_ok {
            let prefix_length = phonelib::decimal_digits(code);
            national(input[1 + prefix_length..], iso, input);
        }
        count++;
        pos = next;
    }
    expect(count == 1143, "all 1143 original reference examples were tested");
}

fn test_reference_validation() {
    var pos = 0;
    var count = 0;
    while pos < REFERENCE_VALIDATION.len {
        let row, next = phonelib::data_row(REFERENCE_VALIDATION, pos);
        let input = phonelib::field(row, 0);
        let expected = phonelib::field(row, 1) == "1";
        let actual = phonelib::is_valid_phone_number(input);
        expect(actual == expected, "validation agrees with reference regexes and lengths");
        if actual != expected { print("  reference disagreement: ", input, " expected ", expected); }
        var out: u8[>..] = [];
        out.append("keep:");
        let ok = phonelib::normalize_phone_number(input, out);
        expect(ok == expected, "normalization and reference validity agree");
        if expected { expect(out[5..] == input, "international digits preserved exactly"); }
        else { expect(out == "keep:", "reference-invalid input does not alter output"); }
        count++;
        pos = next;
    }
    expect(count == 12099, "all independent validation fixtures were tested");
}

fn main() {
    test_metadata();
    test_parsing();
    test_extraction();
    test_metadata_lengths();
    test_generated_inputs();
    test_release_regressions();
    test_reference_examples();
    test_reference_national();
    test_reference_validation();
    print(checks, " checks, ", failures, " failures");
    if failures > 0 { exit(1); }
}
