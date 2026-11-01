# Third-party notices

## Google libphonenumber

Copyright (C) 2009 The Libphonenumber Authors.

The pinned `metadata/libphonenumber/PhoneNumberMetadata.xml` is from
[google/libphonenumber](https://github.com/google/libphonenumber) commit
`1ae0d623301b302f828628dfc368c983e8d27141`, under Apache License 2.0.
The full license is included in `LICENSE.libphonenumber`.

The generated numbering-plan tables, DFA data, updated country length masks,
and reference test fixtures are adaptations of that metadata. They have been
converted for the Goose library; Google does not maintain or endorse this port.

## Rust phonelib

Copyright (c) 2023 Mohamad Al Zohbie.

The original country names and territory-prefix table were adapted from
[mohamadzoh/phonelib](https://github.com/mohamadzoh/phonelib), under the MIT
License. The full notice and license are included in
`LICENSE.rust-phonelib`.
The generated lengths now come from the pinned libphonenumber metadata.
