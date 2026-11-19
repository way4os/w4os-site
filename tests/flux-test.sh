#!/usr/bin/env bash
# The posts of every avatar of the grid in the admin (Flux), end to end, as w4os-wp lists them: the engine's list, its author, its
# date, its search, its delete; for the managers only.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

test_a_god_lists_the_posts_of_the_grid() {
    built || return 0
    sign_in_as "$TMP/god" "God Test"
    local page
    page=$(curl -s -b "$TMP/god" "$URL/w4os/flux")
    assert_contains '<title>Flux Posts' "$page"
    assert_contains 'Opening night at the Plaza' "$page"
    assert_contains 'Hello from Ada' "$page"
    assert_contains 'Ada Love' "$page"
    assert_contains 'placeholder="Search&#x20;Flux&#x20;Posts"' "$page"
    assert_contains 'data-w4os-ask="Delete&#x20;this&#x20;post&#x3F;"' "$page"
}

test_a_resident_never_gets_them() {
    built || return 0
    sign_in_as "$TMP/ada" "Ada Love"
    assert_not_contains 'Opening night at the Plaza' "$(curl -s -L -b "$TMP/ada" "$URL/w4os/flux")"
}
