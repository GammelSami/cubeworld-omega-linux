#!/usr/bin/env bash
# Create a CA for the local proxy and add it to the *prefix's* Windows root store.
# Nothing outside the Cube World Omega prefix is touched.
set -euo pipefail
REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
. "$REPO/scripts/common.sh"

find_mitmdump || die "mitmdump not found, run install.sh"
find_umu || die "umu-run not found, run install.sh"
[ -d "$WINEPREFIX/drive_c" ] || die "prefix $WINEPREFIX does not exist, run install.sh first"

mkdir -p "$CWO_MITM_DIR"
chmod 700 "$CWO_MITM_DIR"
CA="$CWO_MITM_DIR/mitmproxy-ca-cert.pem"
if [ ! -f "$CA" ]; then
    # mitmproxy generates its CA on first start.
    timeout 10 "$MITMDUMP" --listen-host 127.0.0.1 --listen-port 0 --set confdir="$CWO_MITM_DIR" >/dev/null 2>&1 || true
    [ -f "$CA" ] || die "mitmproxy did not create a CA in $CWO_MITM_DIR"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' "$CA" | sed '1d;$d' | base64 -d >"$TMP/ca.der"
SHA1="$(sha1sum "$TMP/ca.der" | cut -c1-40 | tr a-f A-F)"
LEN="$(stat -c %s "$TMP/ca.der")"

# Registry "Blob" = serialized cert element: propid CERT_CERT_PROP_ID (0x20), 1, length, DER.
{
    printf '\x20\x00\x00\x00\x01\x00\x00\x00'
    printf "$(printf '\\x%02x\\x%02x\\x%02x\\x%02x' $((LEN & 255)) $((LEN >> 8 & 255)) $((LEN >> 16 & 255)) $((LEN >> 24 & 255)))"
    cat "$TMP/ca.der"
} >"$TMP/blob"
HEX="$(od -An -v -tx1 "$TMP/blob" | tr -d ' \n' | sed 's/../&,/g; s/,$//')"

REG="$WINEPREFIX/drive_c/cwo-proxy-ca.reg"
printf 'Windows Registry Editor Version 5.00\r\n\r\n[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\SystemCertificates\\Root\\Certificates\\%s]\r\n"Blob"=hex:%s\r\n' \
    "$SHA1" "$HEX" >"$REG"
"${UMU[@]}" regedit /S 'C:\cwo-proxy-ca.reg' >/dev/null 2>&1
rm -f "$REG"
grep -q "$SHA1" "$WINEPREFIX/system.reg" || die "could not add the proxy CA to the prefix"
echo "Proxy CA $SHA1 trusted in $WINEPREFIX"
