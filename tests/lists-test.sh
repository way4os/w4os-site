#!/usr/bin/env bash
# The lists of the admin, end to end: the avatars of the grid as the engine gives them, their views above them (All, then their
# type, whether active, their presence), each value of the other filters with the number of avatars it gives.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

test_a_god_sees_the_avatars_with_their_views_and_the_number_each_value_of_a_filter_gives() {
    built || return 0
    sign_in_as "$TMP/god" "God Test"
    local page
    page=$(curl -s -b "$TMP/god" "$URL/w4os/avatars")
    assert_contains 'Ada Love' "$page"
    # The views above the list, as w4os-wp has them: All, then type, active, presence, the values that give avatars
    assert_contains 'class="list-inline w4os-views' "$page"
    assert_contains '>All <span class="text-secondary">(2)</span></a>' "$page"
    assert_contains '>Resident <span class="text-secondary">(2)</span></a>' "$page"
    assert_contains '>Active <span class="text-secondary">(2)</span></a>' "$page"
    assert_contains '>Online <span class="text-secondary">(1)</span></a>' "$page"
    assert_not_contains 'type=model' "$page"
    # The other filters of the page with the number of avatars each value gives
    assert_contains '<option value="active" data-label="Active">Active (2)</option>' "$page"
    assert_not_contains 'name="online"' "$page"
}
