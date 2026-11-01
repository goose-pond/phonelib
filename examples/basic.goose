import phonelib from "..";

fn main() {
    var e164: u8[>..] = [];
    if phonelib::normalize_phone_number("+1 (202) 555-0173", e164) {
        print("E.164: ", e164);
    }

    let country, found = phonelib::country_from_phone_number("+442079460958");
    if found {
        print("Country: ", country.name, " [", country.code, "]");
    }

    var spans: phonelib::PhoneSpan[>..] = [];
    let count = phonelib::extract_phone_numbers_from_text(
        "Call +1 202-555-0173 or +44 20 7946 0958.", spans);
    print("Found ", count, " international phone numbers");
}
