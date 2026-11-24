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
    # The title of the site, its own name (the one of its grid is ASCII, as its grid info sends it)
    assert_contains 'Welcome to My grid' "$home"
    assert_not_contains '[site-title]' "$home"
    assert_not_contains '[site-slogan]' "$home"
}

test_the_help_page_has_the_connect_block_the_buttons_that_add_the_grid_and_log_in() {
    built || return 0
    local help
    help=$(curl -s "$URL/help")
    assert_contains 'class="w4os-start-step w4os-start-avatar is-next"' "$help"
    assert_contains 'href="hop:///app/gridmanager/addgrid/grid.example.org%3A8002"' "$help"
    assert_contains '<code class="w4os-login-uri">grid.example.org:8002</code>' "$help"
    assert_contains '>Add the grid</a>' "$help"
    assert_contains 'href="secondlife:///app/login?grid=grid.example.org%3A8002"' "$help"
    assert_contains '>Connect</h2>' "$help"
    # The help of w4os.org, whole, under the block: its steps, the viewer, the login URI of the grid
    assert_contains '<h2>1. Create your avatar</h2>' "$help"
    assert_contains '<h2>3. Connect</h2>' "$help"
    assert_contains '<a href="https://www.firestormviewer.org/downloads/">Firestorm</a>, the most used' "$help"
    assert_contains '<h2>1. Crée ton avatar</h2>' "$(curl -s "$URL/fr/help")"
    assert_contains '<h2>1. Erstelle deinen Avatar</h2>' "$(curl -s -L "$URL/de/help")"
    assert_contains '<h2>1. Crea dy afatar</h2>' "$(curl -s -L "$URL/cy/help")"
}
