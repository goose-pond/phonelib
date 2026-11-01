# Contributing

Open an issue for a bug or proposed behavior change. For phone-number bugs,
include the input, country hint if any, expected output, actual output, and
Goose version. Use a public example or a synthetic number rather than a
customer's phone number.

Keep changes focused and add a regression for each corrected behavior.
Expected results should come from a numbering-plan reference or a documented
contract, rather than from the implementation being tested.

## Checks

Install Goose v2026.3 and a C compiler. From the repository root:

```text
goose check examples/basic.goose
goose run tests/phonelib_test.goose --debug --no-bce
goose run tests/phonelib_test.goose -O2
goose build tests/phonelib_test.goose --debug --no-bce -o build/test-debug
goose build tests/phonelib_test.goose -O2 -o build/test-release
./build/test-debug
./build/test-release
```

Build outputs belong under `build/` and must not be committed.

## Numbering-plan changes

Follow [metadata/README.md](metadata/README.md). Update the pinned source and
regenerate the tables and reference fixtures together. Do not hand-edit the
generated binary or relax a regression to accept a known incorrect result.

## Pull requests

Describe the behavior being changed, include a before/after example where
useful, and state which checks ran. Document API changes and update the
changelog. Keep platform claims limited to platforms actually tested.
