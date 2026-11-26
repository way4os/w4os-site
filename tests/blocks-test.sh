#!/usr/bin/env bash
# The blocks of the helpers when the helpers cannot be reached, end to end: the page says it (to a manager the reason and a link to
# Health, to a visitor that the page is unavailable for now when the block is the whole page) and the site logs it.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

set_up() {
    built || return 0
    # The helpers at an address nothing answers
    sed -i.bak -e "/^url:/d" "$SITE/user/config/plugins/w4os.yaml" && rm -f "$SITE/user/config/plugins/w4os.yaml.bak"
    echo "url: 'http://127.0.0.1:$((API_PORT + 2))/helpers'" >>"$SITE/user/config/plugins/w4os.yaml"
}

test_a_manager_is_told_why_the_profile_is_empty_its_status_and_a_link_to_the_diagnostics() {
    built || return 0
    [ -s "$TMP/god" ] || sign_in_as "$TMP/god" "God Test"
    local page
    page=$(curl -s -b "$TMP/god" "$URL/profile")
    # What a failure says: the reason of the transport (nothing answers there), then what was asked
    assert_contains 'Connection refused · helpers: profile <a' "$page"
    assert_contains '>Diagnostics page</a>' "$page"
    assert_contains 'w4os/health' "$page"
    assert_contains 'the block profile of the helpers cannot be read' "$(cat "$SITE"/logs/*.log)"
}

test_a_visitor_is_told_the_page_is_unavailable_for_now_without_the_reason() {
    built || return 0
    [ -s "$TMP/ada" ] || sign_in_as "$TMP/ada" "Ada Love"
    local page
    page=$(curl -s -b "$TMP/ada" "$URL/profile")
    assert_contains 'The grid cannot be reached right now. Please try again later.' "$page"
    assert_not_contains 'helpers: profile' "$page"
}

test_a_manager_is_told_once_for_the_blocks_of_the_home_page_a_visitor_sees_the_page_without_them() {
    built || return 0
    [ -s "$TMP/god" ] || sign_in_as "$TMP/god" "God Test"
    local page
    page=$(curl -s -L -b "$TMP/god" "$URL/")
    assert_equals 1 "$(echo "$page" | grep -o 'Connection refused · helpers: ' | wc -l | tr -d ' ')"
    assert_not_contains 'Connection refused' "$(curl -s -L "$URL/")"
    assert_not_contains 'The grid cannot be reached right now' "$(curl -s -L "$URL/")"
}
