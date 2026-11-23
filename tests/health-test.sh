#!/usr/bin/env bash
# The health page of the admin, end to end: the time of the report the engine kept, and a new one once checked again.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# A recent time as the page tells it: relative where the host lets Carbon run (Grav 2), else the short date with its time (Grav 1.7)
SHORT_DATE='[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}, [0-9]{1,2}:[0-9]{2}[^0-9<]{1,4}[AP]M'

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

test_the_health_says_when_it_was_checked_and_a_new_time_once_checked_again() {
    built || return 0
    sign_in_as "$TMP/god" "God Test"
    local before after
    before=$(curl -s -b "$TMP/god" "$URL/w4os/health")
    assert_matches "checked (1 hour ago|$SHORT_DATE)" "$before"
    assert_contains 'href="/w4os/health?refresh=1"' "$before"
    # The addresses of the grid by their use, then file and section, each its key
    assert_contains '<code>AssetServerURI</code>' "$before"
    assert_contains '<code>Robust.HG.ini</code> <span class="text-secondary">[LoginService]</span>' "$before"
    after=$(curl -s -b "$TMP/god" "$URL/w4os/health?refresh=1")
    assert_not_contains 'checked 1 hour ago' "$after"
    assert_matches "checked ([0-9]+ seconds? ago|$SHORT_DATE)" "$after"
    assert_not_equals "$(grep -oE "checked (1 hour ago|$SHORT_DATE)" <<<"$before" | head -1)" \
        "$(grep -oE "checked ([0-9]+ seconds? ago|$SHORT_DATE)" <<<"$after" | head -1)"
}

test_a_line_of_the_health_is_checked_again_alone_as_the_page_draws_it() {
    built || return 0
    [ -s "$TMP/god" ] || sign_in_as "$TMP/god" "God Test"
    local line
    assert_contains 'data-check="l1"' "$(curl -s -b "$TMP/god" "$URL/w4os/health")"
    line=$(curl -s -b "$TMP/god" "$URL/w4os/health?check=l1")
    assert_contains '<tr data-check="l1" class="w4os-health-ok">' "$line"
    assert_matches "([0-9]+ seconds? ago|$SHORT_DATE)" "$line"
    assert_equals 502 "$(curl -s -o /dev/null -w '%{http_code}' -b "$TMP/god" "$URL/w4os/health?check=nothing")"
    # A visitor is sent to the sign-in, as on every page of the admin
    assert_equals 302 "$(curl -s -o /dev/null -w '%{http_code}' "$URL/w4os/health?check=l1")"
}
