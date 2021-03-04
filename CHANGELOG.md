<!-- Copyright 2018 Google LLC

Use of this source code is governed by an MIT-style
license that can be found in the LICENSE file or at
https://opensource.org/licenses/MIT. -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/).

## Unreleased

### Added
- Exposed getters for RSA public exponent and modulus

## [0.4.3] - 2020-03-26

### Added
- Exposed MD5 digest and HMAC in the `insecure` module.

### Changed
- Documentation on docs.rs now includes all items behind feature flags.

## [0.4.2] - 2019-10-04

### Fixed
- Fixed issue where 0.4.1 was released without updating BoringSSL symbols.
- Fixed issue caused by a bad interaction between `#[derive(Clone)]` and
  `#[deprecated]`.

## [0.4.1] - 2019-09-27

### Added
- `hmac::Hmac` now implements `Clone` and `std::hash::Hasher`, allowing it to be
  used with any type that implements `std::hash::Hash`.
- `hash::Hasher` now similarly implies `Clone` and `std::hash::Hasher`.

## [0.4.0] - 2019-09-25

### Added
- `public::rsa` now supports RSA-PKCS1v1.5 signing (behind the `rsa-pkcs1v15`
  feature flag).
- Added `bytes` module guarded by the `bytes` feature, containing
  `constant_time_eq`.

### Changed
- `build.rs` implements symbol name scraping natively, and no longer relies on
  BoringSSL's `read_symbols.go`.
- Minimum required Rust version raised to 1.36
- Minimum required Go version lowered to 1.10
- Moved `rand_bytes` to `bytes::rand`.
- Removed `rand-bytes` feature in favor of the new feature `bytes`.

### Fixed
- `build.rs` no longer respects `$GOPATH`, instead it always uses the
  `go.mod` from the vendored boringssl.

## [0.3.0] - 2019-02-20

### Added
- Added `public::rsa` module which supports RSA-PSS signing.

### Changed
- In the `public` module, functions to parse and marshal DER-encoded
  public/private keys have been moved from bare functions to methods on the
  `DerPublicKey` and `DerPrivateKey` traits.
- In the `public::ec` module, functions to parse and marshal DER-encoded
  public/private keys as the `EcPubKeyAnyCurve` and `EcPrivKeyAnyCurve` types
  have been moved from bare functions to methods on those types.
- The `public::Signature::verify` method has been renamed to `is_valid` to make
  the meaning of its return value more self-evident.
- The `public::ec` module added experimental support for ECDSA-SHA512 under the
  `experimental-sha512-ec` feature.
