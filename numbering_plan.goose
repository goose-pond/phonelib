import std;
import regex;
namespace phonelib;

struct NumberingPlan {
    length_mask: i64,
    rules_offset: i64,
    national_prefix: const u8[:],
    transform: const u8[:],
    main_region: bool,
}

fn plan_for(country: Country) -> NumberingPlan {
    var pos = 0;
    while pos < PLAN_DATA.len {
        let row, next = data_row(PLAN_DATA, pos);
        if field(row, 0, '\t') == country.code {
            let code, code_ok = parse_int(field(row, 1, '\t'));
            if code_ok && code == country.calling_code {
                let mask, mask_ok = parse_int(field(row, 2, '\t'));
                let offset, offset_ok = parse_int(field(row, 3, '\t'));
                if mask_ok && offset_ok {
                    return NumberingPlan {
                        length_mask: mask, rules_offset: offset,
                        national_prefix: field(row, 4, '\t'), transform: field(row, 5, '\t'),
                        main_region: field(row, 6, '\t') == "true",
                    };
                }
            }
        }
        pos = next;
    }
    return NumberingPlan {
        length_mask: 0, rules_offset: -1, national_prefix: "", transform: "", main_region: false,
    };
}

fn plan_length_ok(plan: NumberingPlan, length: i64) -> bool {
    length > 0 && length <= 15 && (plan.length_mask & (1 << length)) != 0
}

fn rule_u16(at: i64) -> i64 {
    RULE_DATA[at] + (RULE_DATA[at + 1] as i64) * 256
}

// Each 22-byte state has a little-endian u16 accepting flag followed by
// ten u16 transitions. State 65535 is dead; every other state is local to
// this plan's offset. No regex compilation or mutable cache during validation.
fn plan_matches(plan: NumberingPlan, national: const u8[:]) -> bool {
    if plan.rules_offset < 0 || !plan_length_ok(plan, national.len) { return false; }
    var state = 0;
    for digit in national {
        if !is_ascii_digit(digit) { return false; }
        let at = plan.rules_offset + state * 22 + 2 + ((digit - '0') as i64) * 2;
        state = rule_u16(at);
        if state == 65535 { return false; }
    }
    return rule_u16(plan.rules_offset + state * 22) == 1;
}

fn append_national(country: Country, national: const u8[:], out: u8[>..]&) -> bool {
    if decimal_digits(country.calling_code) + national.len > 15 { return false; }
    out.push('+');
    format_int(out, country.calling_code, 10, 0, '0');
    out.append(national);
    return true;
}

// Used only for national input with an explicit region. Upstream prefix rules
// include carrier selection and captured-digit transforms (e.g. AR and BR).
// Goose's regex engine has no anchors: private non-digit sentinels implement
// start and end anchoring without changing capture numbering.
fn transform_national(plan: NumberingPlan, national: const u8[:], out: u8[>..]&) -> bool {
    if plan.national_prefix.len == 0 { return false; }
    var pattern: u8[>..] = [];
    pattern.append("@(?:");
    for c in plan.national_prefix {
        if c == '$' { pattern.push('#'); } else { pattern.push(c); }
    }
    pattern.push(')');
    var input: u8[>..] = [];
    input.push('@');
    input.append(national);
    input.push('#');
    var error: u8[>..] = [];
    let prefix = regex::compile(pattern, error);
    if error.len > 0 { return false; }
    var matched = false;
    regex::each_captures(prefix, input) { caps =>
        var candidate: u8[>..] = [];
        // The last capture determines whether a transformation participated;
        // an unmatched alternative such as '|1' only strips its prefix.
        if plan.transform.len > 0 && caps.slots.len > 2 && caps.slots[caps.slots.len - 2] >= 0 {
            var i = 0;
            while i < plan.transform.len {
                if plan.transform[i] == '$' && i + 1 < plan.transform.len {
                    let group = (plan.transform[i + 1] - '0') as i64;
                    candidate.append(regex::group(caps, group));
                    i += 2;
                } else { candidate.push(plan.transform[i]); i++; }
            }
        }
        let end = min(caps.slots[1], input.len - 1);
        candidate.append(input[end..input.len - 1]);
        if !matched && plan_matches(plan, candidate) {
            out.append(candidate);
            matched = true;
        }
    };
    return matched;
}
