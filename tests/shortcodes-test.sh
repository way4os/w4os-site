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
    assert_contains '[grid-info]' "$page"
    assert_contains 'General information (grid name and login uri)' "$page"
    assert_contains 'Title level (h1 to h6)' "$page"
    assert_contains '[w4os-home]' "$page"
    assert_contains 'include-hypergrid' "$page"
}

test_a_resident_never_gets_it() {
    built || return 0
    sign_in_as "$TMP/ada" "Ada Love"
    assert_not_contains 'Available Shortcodes' "$(curl -s -L -b "$TMP/ada" "$URL/w4os/shortcodes")"
}

test_a_visitor_is_sent_to_sign_in_first() {
    built || return 0
    local jar="$TMP/visitor"
    assert_equals "$URL/login" "$(curl -s -o /dev/null -c "$jar" -b "$jar" -w '%{redirect_url}' "$URL/w4os/shortcodes")"
}

test_the_shortcodes_of_the_site_need_no_closing_slash() {
    built || return 0
    local help home
    help=$(curl -s "$URL/help")
    assert_not_contains '[getting-started]' "$help"
    home=$(curl -s "$URL/")
    assert_contains 'Welcome to Demo Grid' "$home"
    assert_not_contains '[grid-name]' "$home"
    assert_not_contains '[site-slogan]' "$home"
}

test_the_help_page_has_the_connect_block_the_buttons_that_add_the_grid_and_log_in() {
    built || return 0
    local help
    help=$(curl -s "$URL/help")
    assert_contains 'class="w4os-start-step w4os-start-avatar is-next"' "$help"
    assert_contains 'hop&#x3A;&#x2F;&#x2F;&#x2F;app&#x2F;gridmanager&#x2F;addgrid&#x2F;grid.example.org&#x25;3A8002' "$help"
    assert_contains '<code class="w4os-login-uri">grid.example.org:8002</code>' "$help"
    assert_contains '>Add Demo Grid to your viewer</a>' "$help"
    assert_contains 'secondlife&#x3A;&#x2F;&#x2F;&#x2F;app&#x2F;login&#x3F;grid&#x3D;grid.example.org&#x25;3A8002' "$help"
    assert_contains '>Connect</h2>' "$help"
    # The advice on the viewer is text of the help page, under the block
    assert_contains 'No viewer yet? Get <a href="https://www.firestormviewer.org/downloads/">Firestorm</a>' "$help"
    assert_contains 'Pas encore de viewer ? Prenez <a href="https://www.firestormviewer.org/downloads/">Firestorm</a>' "$(curl -s "$URL/fr/help")"
}
