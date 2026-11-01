import phonelib from "..";

fn main() {
    let e164, normalized = phonelib::normalized_phone_number("+1 (202) 555-0173");
    if normalized {
        print("E.164: ", e164);
    }

    let national, parsed = phonelib::parse_with_country("01 234 567", "LB");
    if parsed { print("National input country: ", national.country.code); }

    let country, found = phonelib::country_from_phone_number("+442079460958");
    if found {
        print("Country: ", country.name, " [", country.code, "]");
    }

    let spans = phonelib::extracted_phone_numbers_from_text(
        "Call +1 202-555-0173 or +44 20 7946 0958.");
    print("Found ", spans.len, " international phone numbers");
}
