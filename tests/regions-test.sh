#!/usr/bin/env bash
# The page of a region in the admin, end to end: its parcels as a tab, as w4os-wp shows them on its page.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

test_a_region_shows_its_parcels_in_a_tab() {
    built || return 0
    sign_in_as "$TMP/god" "God Test"
    local page parcels
    page=$(curl -s -b "$TMP/god" "$URL/w4os/regions/region?id=r1")
    assert_contains 'Test East' "$page"
    assert_contains '>Parcels</a>' "$page"
    parcels=$(curl -s -b "$TMP/god" "$URL/w4os/regions/region?id=r1&tab=parcels")
    assert_contains 'Plaza' "$parcels"
    assert_contains '1 parcels' "$parcels"
    assert_contains 'aria-current="page">Parcels</a>' "$parcels"
}
