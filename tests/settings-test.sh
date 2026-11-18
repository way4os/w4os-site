#!/usr/bin/env bash
# The settings of the site, end to end: a god opens them in the admin of the site (the w4os plugin) and finds the theme among the
# ones installed, the site's chosen; a resident never gets them.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

test_a_god_finds_the_theme_among_the_ones_installed_the_site_s_chosen_under_the_title_of_the_page() {
    built || return 0
    local page
    sign_in_as "$TMP/god" "God Test"
    page=$(curl -s -b "$TMP/god" "$URL/account/settings")
    assert_contains "<title>Site settings" "$page"
    assert_not_contains "w4os.settings_title" "$page"
    assert_contains "Theme" "$page"
    assert_matches '<option [^>]*selected[^>]*value="w4os"[^>]*>w4os site</option>' "$page"
    assert_matches '<option +value="quark2"[^>]*>Quark 2</option>' "$page"
}

test_a_resident_never_gets_them() {
    built || return 0
    sign_in_as "$TMP/ada" "Ada Love"
    assert_equals 302 "$(curl -s -o /dev/null -w '%{http_code}' -b "$TMP/ada" "$URL/account/settings")"
}
