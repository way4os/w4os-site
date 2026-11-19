#!/usr/bin/env bash
# The page of the shortcodes in the admin, end to end: each shortcode with what it shows and its options, for the managers only.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

test_a_manager_finds_the_shortcodes_with_what_they_show_and_their_options() {
    built || return 0
    sign_in_as "$TMP/god" "God Test"
    local page
    page=$(curl -s -b "$TMP/god" "$URL/w4os/shortcodes")
    assert_contains '<title>Available Shortcodes' "$page"
    assert_contains '[w4os block=&quot;grid-info&quot; /]' "$page"
    assert_contains 'General information (grid name and login uri)' "$page"
    assert_contains 'Title level (h1 to h6)' "$page"
    assert_contains '[w4os-home]' "$page"
}

test_a_resident_never_gets_it() {
    built || return 0
    sign_in_as "$TMP/ada" "Ada Love"
    assert_not_contains 'Available Shortcodes' "$(curl -s -L -b "$TMP/ada" "$URL/w4os/shortcodes")"
}
