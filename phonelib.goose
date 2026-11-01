import std;
import regex;
import numbering_plan;
namespace phonelib;

// Generated from pinned libphonenumber metadata; see metadata/README.md.
// All data is embedded. Validation uses immutable decimal DFA transitions.
const COUNTRY_DATA = embed_file("regions.tsv");
const PLAN_DATA = embed_file("numbering_plans.tsv");
const RULE_DATA = embed_file("numbering_rules.bin");
const REGIONAL_ENTRY_COUNT = 250;
const GLOBAL_SERVICE_COUNT = 9;
const COUNTRY_COUNT = REGIONAL_ENTRY_COUNT + GLOBAL_SERVICE_COUNT;

struct Country {
    name: const u8[:],
    code: const u8[:],
    // The ITU country calling code (1 for NANP territories).
    calling_code: i64,
    // Prefix written after '+' before local subscriber digits. For NANP
    // territories it includes the country code and area code (e.g. 1268).
    e164_prefix: i64,
    // Accepted lengths after e164_prefix. Zero means lookup-only metadata.
    length_mask: i64,
    global_service: bool,
}

struct PhoneNumber {
    // E.164 digits without the leading plus sign.
    digits: u8[15],
    digit_count: i64,
    // Number of leading digits in Country.calling_code, not e164_prefix.
    calling_code_length: i64,
    country: Country,
    country_is_ambiguous: bool,
}

struct PhoneSpan {
    // Half-open byte offsets into the input text.
    start: i64,
    end: i64,
}

enum PhoneFormat { E164, International, National, RFC3966 }

fn empty_country() -> Country {
    Country {
        name: "", code: "", calling_code: 0, e164_prefix: 0,
        length_mask: 0, global_service: false,
    }
}

fn empty_phone_number() -> PhoneNumber {
    PhoneNumber {
        digits: [0; 15],
        digit_count: 0,
        calling_code_length: 0,
        country: empty_country(),
        country_is_ambiguous: false,
    }
}

fn data_row(data: const u8[:], start: i64) -> const u8[:], i64 {
    var end = start;
    while end < data.len && data[end] != '\n' { end++; }
    if end < data.len { return data[start..end], end + 1; }
    return data[start..end], end;
}

fn next_row(start: i64) -> const u8[:], i64 {
    let row, next = data_row(COUNTRY_DATA, start);
    return row, next;
}

fn field(row: const u8[:], wanted: i64, separator: u8 = '|') -> const u8[:] {
    var start = 0;
    var index = 0;
    var i = 0;
    while i <= row.len {
        if i == row.len || row[i] == separator {
            if index == wanted { return row[start..i]; }
            start = i + 1;
            index++;
        }
        i++;
    }
    return row[0..0];
}

fn country_from_row(row: const u8[:]) -> Country {
    if row.len == 0 { return empty_country(); }
    let code = field(row, 0);
    let prefix, prefix_ok = parse_int(field(row, 1));
    let mask, mask_ok = parse_int(field(row, 2));
    if !prefix_ok || !mask_ok { return empty_country(); }
    let calling_code = if prefix >= 1000 && prefix < 2000 { 1 } else { prefix };
    return Country {
        name: field(row, 3),
        code: code,
        calling_code: calling_code,
        e164_prefix: prefix,
        length_mask: mask,
        global_service: code == "001",
    };
}

fn country_count() -> i64 { COUNTRY_COUNT }

fn country_at(index: i64) -> Country {
    if index < 0 || index >= COUNTRY_COUNT { return empty_country(); }
    var row_index = 0;
    var pos = 0;
    while row_index <= index && pos < COUNTRY_DATA.len {
        let row, next = next_row(pos);
        if row_index == index { return country_from_row(row); }
        row_index++;
        pos = next;
    }
    return empty_country();
}

fn append_countries(out: Country[>..]&) -> i64 {
    var row_index = 0;
    var pos = 0;
    while row_index < COUNTRY_COUNT && pos < COUNTRY_DATA.len {
        let row, next = next_row(pos);
        out.push(country_from_row(row));
        row_index++;
        pos = next;
    }
    return row_index;
}

fn country_by_iso_code(code: const u8[:]) -> Country, bool {
    var row_index = 0;
    var pos = 0;
    while row_index < COUNTRY_COUNT && pos < COUNTRY_DATA.len {
        let row, next = next_row(pos);
        let country = country_from_row(row);
        if country.code == code && !country.global_service { return country, true; }
        row_index++;
        pos = next;
    }
    return empty_country(), false;
}

fn countries_by_calling_code(code: i64, out: Country[>..]&) -> i64 {
    var row_index = 0;
    var found = 0;
    var pos = 0;
    while row_index < COUNTRY_COUNT && pos < COUNTRY_DATA.len {
        let row, next = next_row(pos);
        let country = country_from_row(row);
        if country.calling_code == code {
            out.push(country);
            found++;
        }
        row_index++;
        pos = next;
    }
    return found;
}

fn countries_by_iso_code(code: const u8[:], out: Country[>..]&) -> i64 {
    var row_index = 0;
    var found = 0;
    var pos = 0;
    while row_index < COUNTRY_COUNT && pos < COUNTRY_DATA.len {
        let row, next = next_row(pos);
        let country = country_from_row(row);
        if country.code == code && !country.global_service {
            out.push(country);
            found++;
        }
        row_index++;
        pos = next;
    }
    return found;
}

fn is_ascii_digit(c: u8) -> bool { c >= '0' && c <= '9' }

fn is_number_separator(c: u8) -> bool {
    c == ' ' || c == '\t' || c == '\r' || c == '\n' ||
    c == '-' || c == '.' || c == '/' || c == '(' || c == ')'
}

fn collect_digits(text: const u8[:], digits: u8[20]&) -> i64, bool, bool {
    var count = 0;
    var has_plus = false;
    var saw_non_space = false;
    var i = 0;
    while i < text.len {
        let c = text[i];
        if c == '+' {
            if has_plus || count != 0 || saw_non_space { return count, has_plus, false; }
            has_plus = true;
            saw_non_space = true;
        } else if is_ascii_digit(c) {
            if count >= digits.len { return count, has_plus, false; }
            digits[count] = c;
            count++;
            saw_non_space = true;
        } else if !is_number_separator(c) {
            return count, has_plus, false;
        }
        i++;
    }
    return count, has_plus, count > 0;
}

fn decimal_digits(value: i64) -> i64 {
    var n = value;
    var count = 1;
    while n >= 10 { n /= 10; count++; }
    return count;
}

fn prefix_text_matches(digits: u8[20], start: i64, count: i64, prefix: const u8[:]) -> bool {
    if count <= prefix.len { return false; }
    for i in prefix.len {
        if digits[start + i] != prefix[i] { return false; }
    }
    return true;
}

fn resolve_digits(digits: u8[20], start: i64, count: i64, require_valid: bool = true) -> Country, bool, bool {
    var best = empty_country();
    var best_length = 0;
    var valid_matches = 0;
    var row_index = 0;
    var pos = 0;
    while row_index < COUNTRY_COUNT && pos < COUNTRY_DATA.len {
        let row, next = next_row(pos);
        let prefix_text = field(row, 1);
        let candidate_length = prefix_text.len;
        if prefix_text_matches(digits, start, count, prefix_text) {
            let candidate = country_from_row(row);
            let plan = plan_for(candidate);
            let calling_length = decimal_digits(candidate.calling_code);
            let national = digits[start + calling_length..start + count];
            let accepted = if require_valid { plan_matches(plan, national) }
                           else { plan_length_ok(plan, national.len) };
            if accepted && candidate_length >= best_length {
                if candidate_length > best_length {
                    best_length = candidate_length;
                    valid_matches = 0;
                }
                valid_matches++;
                if valid_matches == 1 || plan.main_region {
                    best = candidate;
                }
            }
        }
        row_index++;
        pos = next;
    }
    if valid_matches == 0 { return empty_country(), false, false; }
    return best, valid_matches > 1, true;
}

fn has_valid_national_length(country: Country, length: i64) -> bool {
    return length > 0 && length <= 15 && (country.length_mask & (1 << length)) != 0;
}

fn is_nanp_prefix(prefix: i64) -> bool { return prefix == 1 || (prefix >= 1000 && prefix < 2000); }

fn parse_number(text: const u8[:], require_valid: bool) -> PhoneNumber, bool {
    var digits: u8[20] = [0; 20];
    let raw_count, has_plus, ok = collect_digits(text, digits);
    if !ok { return empty_phone_number(), false; }
    var start = 0;
    var explicit_international = has_plus;
    if !has_plus && raw_count >= 2 && digits[0] == '0' && digits[1] == '0' {
        start = 2;
        explicit_international = true;
    }
    let count = raw_count - start;
    if count > 15 { return empty_phone_number(), false; }
    let country, ambiguous, found = resolve_digits(digits, start, count, require_valid);
    if !found { return empty_phone_number(), false; }
    if !explicit_international && !is_nanp_prefix(country.e164_prefix) {
        return empty_phone_number(), false;
    }
    // International input is canonical: preserve every collected digit.
    // Trunk removal and rewriting belong exclusively to normalize_with_country.
    var number = empty_phone_number();
    for i in count { number.digits[i] = digits[start + i]; }
    number.digit_count = count;
    number.calling_code_length = decimal_digits(country.calling_code);
    number.country = country;
    number.country_is_ambiguous = ambiguous;
    return number, true;
}

fn parse_phone_number(text: const u8[:]) -> PhoneNumber, bool {
    let number, ok = parse_number(text, true);
    return number, ok;
}

// Length-only possibility is deliberately separate from prefix validation.
fn is_possible_phone_number(text: const u8[:]) -> bool {
    let number, ok = parse_number(text, false);
    return ok;
}

fn is_valid_phone_number(text: const u8[:]) -> bool {
    let number, ok = parse_phone_number(text);
    return ok;
}

fn country_from_phone_number(text: const u8[:]) -> Country, bool {
    let number, ok = parse_phone_number(text);
    if !ok { return empty_country(), false; }
    return number.country, true;
}

fn phone_number_country_is_ambiguous(text: const u8[:]) -> bool {
    let number, ok = parse_phone_number(text);
    return ok && number.country_is_ambiguous;
}

fn calling_code_from_phone_number(text: const u8[:]) -> i64, bool {
    let number, ok = parse_phone_number(text);
    if !ok { return 0, false; }
    return number.country.calling_code, true;
}

fn format_parsed_phone_number(number: PhoneNumber, format: PhoneFormat, out: u8[>..]&) {
    if format == PhoneFormat.RFC3966 { out.append("tel:"); }
    if format != PhoneFormat.National { out.push('+'); }
    if format == PhoneFormat.International {
        format_int(out, number.country.calling_code, 10, 0, '0');
        out.push(' ');
        out.append(number.digits[number.calling_code_length..number.digit_count]);
    } else if format == PhoneFormat.National {
        out.append(number.digits[number.calling_code_length..number.digit_count]);
    } else {
        out.append(number.digits[..number.digit_count]);
    }
}

fn format_phone_number(text: const u8[:], format: PhoneFormat, out: u8[>..]&) -> bool {
    let number, ok = parse_phone_number(text);
    if !ok { return false; }
    format_parsed_phone_number(number, format, out);
    return true;
}

fn normalize_phone_number(text: const u8[:], out: u8[>..]&) -> bool {
    return format_phone_number(text, PhoneFormat.E164, out);
}

fn normalized_phone_number(text: const u8[:]) -> u8[>..], bool {
    var out: u8[>..] = [];
    if !normalize_phone_number(text, out) { return out, false; }
    return out, true;
}

fn normalize_with_country(text: const u8[:], iso_code: const u8[:], out: u8[>..]&) -> bool {
    var digits: u8[20] = [0; 20];
    let raw_count, has_plus, ok = collect_digits(text, digits);
    if !ok { return false; }
    if has_plus || (raw_count >= 2 && digits[0] == '0' && digits[1] == '0') {
        return normalize_phone_number(text, out);
    }
    let country, found = country_by_iso_code(iso_code);
    if !found { return false; }
    let plan = plan_for(country);
    let national = digits[..raw_count];
    // A valid national significant number is already canonical. In particular,
    // do not remove a meaningful leading zero (Italy) or a service prefix.
    if plan_matches(plan, national) { return append_national(country, national, out); }
    var transformed: u8[>..] = [];
    if transform_national(plan, national, transformed) {
        return append_national(country, transformed, out);
    }
    // Preserve the local seven-digit API for NANP territories, including
    // regions with multiple area codes; the first listed prefix is the default.
    if country.e164_prefix != country.calling_code {
        var local: u8[>..] = [];
        format_int(local, country.e164_prefix, 10, 0, '0');
        local.append(national);
        let nsn = local[decimal_digits(country.calling_code)..];
        if plan_matches(plan, nsn) { return append_national(country, nsn, out); }
    }
    return false;
}

fn is_word_byte(c: u8) -> bool {
    return is_ascii_digit(c) || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_';
}

fn candidate_byte(c: u8) -> bool { return is_ascii_digit(c) || is_number_separator(c) || c == '+'; }

fn candidate_starts(text: const u8[:], at: i64) -> bool {
    let c = text[at];
    if at > 0 && (is_word_byte(text[at - 1]) || text[at - 1] == '+') { return false; }
    if c != '+' { return c == '0' && at + 1 < text.len && text[at + 1] == '0'; }
    var next = at + 1;
    while next < text.len && is_number_separator(text[next]) { next++; }
    return next < text.len && is_ascii_digit(text[next]);
}

// Appends valid international phone-number spans and returns the number added.
// The scan is one pass over the input; returned offsets refer to UTF-8 bytes.
fn extract_phone_numbers_from_text(text: const u8[:], out: PhoneSpan[>..]&) -> i64 {
    let old_length = out.len;
    var i = 0;
    while i < text.len {
        if !candidate_starts(text, i) { i++; continue; }
        let start = i;
        var end = i;
        var last_digit = -1;
        var digit_count = 0;
        while end < text.len && candidate_byte(text[end]) && (end == start || text[end] != '+') {
            // A separated 00 prefix can begin another international number.
            // Only split after a complete valid number, not inside its digits.
            if end > start && text[end] == '0' && candidate_starts(text, end) &&
               last_digit >= start && digit_count <= 17 &&
               is_valid_phone_number(text[start..last_digit + 1]) {
                break;
            }
            if is_ascii_digit(text[end]) {
                last_digit = end;
                digit_count++;
            }
            end++;
        }
        if last_digit >= start && digit_count <= 17 {
            let word_suffix = last_digit + 1 < text.len && is_word_byte(text[last_digit + 1]);
            if !word_suffix && is_valid_phone_number(text[start..last_digit + 1]) {
                out.push(PhoneSpan { start: start, end: last_digit + 1 });
            }
        }
        // Skip the complete candidate even if it is too long or invalid.
        i = end;
    }
    return out.len - old_length;
}
