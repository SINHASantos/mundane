#!/bin/bash

# Copyright 2018 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

set -e

# cd to the directory this script lives in
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ $# -ne 3 ]; then
    echo "Usage: $0 <major> <minor> <patch>" >&2
    exit 1
fi

MAJOR="$1"
MINOR="$2"
PATCH="$3"

# TODO(joshlf):
# - Use the --use-core flag once std isn't required (see
#   https://github.com/rust-lang-nursery/rust-bindgen/issues/1015)

# Only include the symbols we want. It's important that we take the minimum
# dependency on BoringSSL so that we provide the minimum burden for them. The
# more symbols we depend on, the more likely it is that a change that they want
# to make will affect us, which they will care about, making them either expend
# effort in a graceful transition or decide to abandon the change. Thus, instead
# of allowing broad classes of symbols, we explicitly allow the exact list of
# symbols that Mundane depends on.

# TODO(inejge):
# - When https://github.com/rust-lang-nursery/rust-bindgen/issues/1375 is resolved,
#   go back to a single allowlist

# Split the allowlist into function names and other symbols, in order to use the
# former for a consistency check of the postprocessing step which adds the
# #[link_name...] attributes. Any change of the allowlist must be made to the
# appropriate sub-list.
ALLOWLIST_FUNCS="BN_bn2bin_padded|\
BN_free|\
BN_init|\
BN_num_bytes|\
BN_set_u64|\
CBS_init|\
CBS_len|\
CBB_init|\
CBB_cleanup|\
CBB_data|\
CBB_len|\
ED25519_keypair|\
ED25519_sign|\
ED25519_verify|\
ED25519_keypair_from_seed|\
EC_GROUP_new_by_curve_name|\
EC_GROUP_get_curve_name|\
EC_curve_nid2nist|\
EC_KEY_new|\
EC_KEY_free|\
EC_KEY_up_ref|\
EC_KEY_get0_group|\
EC_KEY_set_group|\
EC_KEY_generate_key|\
EC_KEY_parse_private_key|\
EC_KEY_marshal_private_key|\
ECDSA_sign|\
ECDSA_verify|\
ECDSA_size|\
ERR_print_errors_cb|\
EVP_md5|\
EVP_sha1|\
EVP_sha256|\
EVP_sha384|\
EVP_sha512|\
EVP_PKEY_new|\
EVP_PKEY_free|\
EVP_PKEY_up_ref|\
EVP_PKEY_assign_EC_KEY|\
EVP_PKEY_assign_RSA|\
EVP_PKEY_get1_EC_KEY|\
EVP_PKEY_get1_RSA|\
EVP_parse_public_key|\
EVP_marshal_public_key|\
PKCS5_PBKDF2_HMAC|\
EVP_PBE_scrypt|\
HMAC_CTX_init|\
HMAC_CTX_cleanup|\
HMAC_CTX_copy|\
HMAC_Init_ex|\
HMAC_Update|\
HMAC_Final|\
HMAC_size|\
CRYPTO_memcmp|\
MD5_Final|\
MD5_Init|\
MD5_Transform|\
MD5_Update|\
RAND_bytes|\
RC4|\
RC4_set_key|\
RSA_bits|\
RSA_free|\
RSA_generate_key_ex|\
RSA_get0_e|\
RSA_get0_n|\
RSA_marshal_private_key|\
RSA_new|\
RSA_parse_private_key|\
RSA_sign|\
RSA_sign_pss_mgf1|\
RSA_size|\
RSA_up_ref|\
RSA_verify|\
RSA_verify_pss_mgf1|\
SHA1_Init|\
SHA1_Update|\
SHA1_Final|\
SHA256_Init|\
SHA256_Update|\
SHA256_Final|\
SHA384_Init|\
SHA384_Update|\
SHA384_Final|\
SHA512_Init|\
SHA512_Update|\
SHA512_Final"

ALLOWLIST_OTHERS="BIGNUM|\
BN_GENCB|\
CBB|\
CBS|\
EC_GROUP|\
EC_KEY|\
ED25519_PRIVATE_KEY_LEN|\
ED25519_PUBLIC_KEY_LEN|\
ED25519_SIGNATURE_LEN|\
EVP_MD|\
EVP_PKEY|\
HMAC_CTX|\
MD5_CTX|\
MD5_DIGEST_LENGTH|\
NID_md5|\
NID_X9_62_prime256v1|\
NID_secp384r1|\
NID_secp521r1|\
NID_sha1|\
NID_sha256|\
NID_sha384|\
NID_sha512|\
RC4_KEY|\
RSA|\
RSA_F4|\
SHA_CTX|\
SHA_DIGEST_LENGTH|\
SHA256_CTX|\
SHA256_DIGEST_LENGTH|\
SHA512_CTX|\
SHA384_DIGEST_LENGTH|\
SHA512_CTX|\
SHA512_DIGEST_LENGTH"

ALLOWLIST="(${ALLOWLIST_FUNCS}|${ALLOWLIST_OTHERS})"

# NOTE(joshlf): We pin to a particular version of bindgen since updates
# sometimes change the semantics of the generated bindings (for example, by
# changing the Rust types that are generated for particular C types). If a more
# recent version of bindgen is available, "roll" bindgen by updating the
# `BINDGEN_EXPECTED_VERSION` variable here.
BINDGEN_EXPECTED_VERSION="bindgen 0.59.2"
BINDGEN_GOT_VERSION="$(bindgen --version)"
if [ "$BINDGEN_GOT_VERSION" != "$BINDGEN_EXPECTED_VERSION" ]; then
    echo "Unexpected version of bindgen: got $BINDGEN_GOT_VERSION; wanted $BINDGEN_EXPECTED_VERSION.
If a newer version is available, edit this script to pin to that version." >&2
    exit 1
fi

# NOTE(joshlf): Currently, we don't pass --target since none of the symbols
# we're linking against are architecture-specific (TODO: are any of them
# word-size-specific?). If this ever becomes a problem, then the thing to do is
# probably to generate different files for different platforms
# (boringssl_x86_64.rs, boringssl_arm64.rs, etc) and conditionally compile them
# depending on target.
bindgen bindgen.h --whitelist-function "$ALLOWLIST" --whitelist-type "$ALLOWLIST" \
    --whitelist-var "$ALLOWLIST" -o boringssl.rs -- -I ./boringssl/include

TMP="$(mktemp)"

# Prepend copyright comment, #[allow] for various warnings we don't care about,
# and a line telling Rust to link against libcrypto.
(cat <<'EOF'
// Copyright 2018 Google LLC
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// Some symbols are only used with certain features enabled, so we need to
// suppress the unused warning when those features aren't enabled.
#![allow(unused)]
// Only necessary for test_symbol_conflict.sh, which exposes these symbols
// through Mundane's public interface.
#![allow(missing_docs)]
// TODO(https://github.com/rust-lang/rust-bindgen/issues/1651): Remove this
// once rustc doesn't think that bindgen's tests are causing UB.
#![cfg_attr(test, allow(deref_nullptr))]
#![allow(non_camel_case_types)]
#![allow(non_snake_case)]
#![allow(non_upper_case_globals)]
#![allow(clippy::all)]

EOF

# Do this on a separate line because we need string interpolation, but we can't
# use string interpolation in the preceding 'cat' command, or else the !
# characters would be interpreted.
echo "#[link(name = \"crypto_${MAJOR}_${MINOR}_${PATCH}\")] extern {}"
echo

cat boringssl.rs) \
| rustfmt \
| (
# Postprocess the generated bindings, adding the "#[link_name ...]"
# attribute to exported functions. Since the function sites are matched
# lexically, check the consistency of matches against the list of function
# names defined above. An error will be returned if:
#
# a) a matched function is not in the allowlist
# b) a name from the allowlist wasn't matched in the input, or
# c) a name was matched more than once (which should never happen).
awk -v "vers=${MAJOR}_${MINOR}_${PATCH}_" -v "funcs=${ALLOWLIST_FUNCS}" '
BEGIN {
    split(funcs, fa, "[|]")
    for (fn in fa)
        f[fa[fn]]
}
/extern "C" {/ {
    print
    getline
    if ($0 ~ "#[[]link_name")
        getline
    if ($0 ~ "pub fn") {
        fn = $3
        sub("[(].*", "", fn)
        if (!(fn in f)) {
            print "fatal: fn not in allowlist: " fn | "cat >&2"
            exit 1
        } else
            f[fn]++
        print "    #[link_name = \"__RUST_MUNDANE_" vers fn "\"]"
    }
}
{ print }
END {
    for (fn in f)
        if (f[fn] != 1) {
            print "fatal: fn match count = " f[fn] + 0 ", should be 1: " fn | "cat >&2"
            exit 1
        }
}') > "$TMP"
mv "$TMP" boringssl.rs
