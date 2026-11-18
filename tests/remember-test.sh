#!/usr/bin/env bash
# Signing in and staying signed in, end to end: the Grav tree built (build/w4os-site/grav, or W4OS_SITE_BUILD) as the zip has
# it (site_tree), served by php alone with several workers, its engine a fake API (tests/fixtures/api.php). Each cookie jar is a browser.

# The Grav tree served with its fake engine (tests/site.sh)
# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in JAR: Ada Love signs in with "remember me" in the browser JAR; prints the status of the answer
sign_in() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -w '%{http_code}' -c "$jar" -b "$jar" "$URL/login" \
        --data-urlencode "username=Ada Love" --data-urlencode "password=secret" -d "rememberme=1" -d "task=login.login" \
        --data-urlencode "login-form-nonce=$nonce"
}

# who JAR [OUT]: the page of the sign-in as the browser JAR sees it (signed in: its logout link), its cookies kept in OUT
who() {
    curl -s -c "${2:-$1}" -b "$1" "$URL/login"
}

# The sessions forgotten, as after a day without a visit: only "remember me" brings the browsers back
forget_sessions() {
    rm -f "$SITE"/user/data/sessions/sess_*
}

signed_in() {
    assert_contains "task:login.logout" "$1"
}

test_two_browsers_stay_signed_in_at_once() {
    built || return 0
    assert_equals 303 "$(sign_in "$TMP/a")"
    assert_equals 303 "$(sign_in "$TMP/b")"
    forget_sessions
    signed_in "$(who "$TMP/a")"
    signed_in "$(who "$TMP/b")"
    forget_sessions
    signed_in "$(who "$TMP/a")"
    signed_in "$(who "$TMP/b")"
}

test_a_browser_back_by_remember_me_stays_signed_in_on_the_next_pages() {
    built || return 0
    assert_equals 303 "$(sign_in "$TMP/e")"
    forget_sessions
    signed_in "$(who "$TMP/e")"
    signed_in "$(who "$TMP/e")"
    assert_equals 200 "$(curl -s -o /dev/null -w '%{http_code}' -c "$TMP/e" -b "$TMP/e" "$URL/")"
}

test_a_browser_sending_requests_at_once_stays_signed_in() {
    built || return 0
    assert_equals 303 "$(sign_in "$TMP/c")"
    forget_sessions
    local i requests=()
    for i in 1 2 3 4; do
        curl -s -o "$TMP/c$i.html" -w '%{http_code}\n' -c "$TMP/c$i" -b "$TMP/c" "$URL/login" >"$TMP/c$i.status" &
        requests+=($!)
    done
    wait "${requests[@]}"
    for i in 1 2 3 4; do
        assert_equals 200 "$(cat "$TMP/c$i.status")"
        signed_in "$(cat "$TMP/c$i.html")"
    done
    # Whichever answer the browser kept, it is still signed in later
    for i in 1 2 3 4; do
        forget_sessions
        signed_in "$(who "$TMP/c$i")"
    done
}

test_a_stolen_cookie_lands_on_the_sign_in_page_with_a_message_and_signs_out_everywhere() {
    built || return 0
    assert_equals 303 "$(sign_in "$TMP/d")"
    forget_sessions
    # A cookie of the same series with a token it never had
    sed -E 's/(grav-rememberme	[^%]*%7C)[0-9a-f]+(%7C)/\1forged00000000000000000000000000000000000\2/' "$TMP/d" >"$TMP/thief"
    assert_not_equals "$(cat "$TMP/d")" "$(cat "$TMP/thief")"
    local page
    page=$(curl -s -L -c "$TMP/thief" -b "$TMP/thief" "$URL/login")
    assert_not_contains "Server Error" "$page"
    assert_contains 'name="login-form-nonce"' "$page"
    assert_contains "Someone else has used your login information" "$page"
    forget_sessions
    assert_not_contains "task:login.logout" "$(who "$TMP/d")"
}
