#!/usr/bin/env bash
# The dashboard of the admin, end to end: its cards in their order, in columns; the regions and the simulators online of all, the
# counts of the avatars in one card by their plain names, the recent avatars with a link to them all.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

test_a_god_sees_the_counts_of_the_avatars_in_one_card_and_the_recent_avatars() {
    built || return 0
    sign_in_as "$TMP/god" "God Test"
    local page
    page=$(curl -s -b "$TMP/god" "$URL/w4os" | sed 's#&\#x2F;#/#g; s#&\#x3F;#?#g; s#&\#x3D;#=#g')
    assert_contains 'class="w4os-dashboard"' "$page"
    assert_equals 1 "$(grep -c 'Service Account' <<<"$page")"
    assert_contains '/w4os/avatars?status=pending"' "$page"
    assert_contains 'Recent Avatars' "$page"
    assert_contains 'See all' "$page"
    assert_not_contains 'row-deck' "$page"
}

test_a_god_sees_the_simulators_and_the_regions_running_of_all_and_their_list() {
    built || return 0
    sign_in_as "$TMP/god2" "God Test"
    local page list
    page=$(curl -s -b "$TMP/god2" "$URL/w4os")
    assert_equals 2 "$(grep -c '>2/3<' <<<"$page")"
    list=$(curl -s -b "$TMP/god2" "$URL/w4os/simulators")
    assert_contains 'Plaza' "$list"
    assert_contains 'Sandbox' "$list"
}
