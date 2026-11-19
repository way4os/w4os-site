#!/usr/bin/env bash
# The health page of the admin, end to end: the time of the report the engine kept, and a new one once checked again.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

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
    assert_contains 'checked 1 hour ago' "$before"
    assert_contains 'href="/w4os/health?refresh=1"' "$before"
    after=$(curl -s -b "$TMP/god" "$URL/w4os/health?refresh=1")
    assert_not_contains 'checked 1 hour ago' "$after"
    assert_matches 'checked [0-9]+ seconds? ago' "$after"
}

test_a_line_of_the_health_is_checked_again_alone_as_the_page_draws_it() {
    built || return 0
    [ -s "$TMP/god" ] || sign_in_as "$TMP/god" "God Test"
    local line
    assert_contains 'data-check="l1"' "$(curl -s -b "$TMP/god" "$URL/w4os/health")"
    line=$(curl -s -b "$TMP/god" "$URL/w4os/health?check=l1")
    assert_contains '<tr data-check="l1" class="w4os-health-ok">' "$line"
    assert_matches '[0-9]+ seconds? ago' "$line"
    assert_equals 502 "$(curl -s -o /dev/null -w '%{http_code}' -b "$TMP/god" "$URL/w4os/health?check=nothing")"
    # A visitor is sent to the sign-in, as on every page of the admin
    assert_equals 302 "$(curl -s -o /dev/null -w '%{http_code}' "$URL/w4os/health?check=l1")"
}
