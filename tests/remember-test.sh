#!/usr/bin/env bash
# Signing in and staying signed in, end to end: the Grav tree built (build/w4os-site/grav, or W4OS_SITE_BUILD) as the zip has
# it (site_tree), served by php alone with several workers, its engine a fake API (tests/fixtures/api.php). Each cookie jar is a browser.

set_up_before_script() {
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    GRAV_TREE=${W4OS_SITE_BUILD:-$ROOT/build/w4os-site/grav}
    [ -f "$GRAV_TREE/index.php" ] || return 0
    STALE=$(stale "$GRAV_TREE")
    [ -z "$STALE" ] || return 0
    TMP=$(mktemp -d)
    # shellcheck source=../packaging/zip.sh
    source "$ROOT/packaging/zip.sh"
    SITE="$TMP/w4os-site"
    site_tree "$GRAV_TREE" "$ROOT/defaults" "$SITE"
    API_PORT=$((20000 + RANDOM % 20000))
    PORT=$((API_PORT + 1))
    php -S "127.0.0.1:$API_PORT" "$ROOT/tests/fixtures/api.php" >/dev/null 2>&1 &
    API_PID=$!
    cat >>"$SITE/user/config/plugins/w4os.yaml" <<EOF
api_url: 'http://127.0.0.1:$API_PORT/api'
api_key: osk_test
EOF
    sed -i.bak -e "s/^api_url: ''$//" "$SITE/user/config/plugins/w4os.yaml" && rm "$SITE/user/config/plugins/w4os.yaml.bak"
    (cd "$SITE" && PHP_CLI_SERVER_WORKERS=4 exec php -S "127.0.0.1:$PORT" system/router.php >/dev/null 2>&1) &
    SITE_PID=$!
    URL="http://127.0.0.1:$PORT"
    local tries=100
    until curl -s -o /dev/null "$URL/" || [ $((tries -= 1)) -eq 0 ]; do sleep 0.2; done
}

tear_down_after_script() {
    # The server's workers are its children
    pkill -P "${SITE_PID:-0}" 2>/dev/null || true
    kill "${SITE_PID:-}" "${API_PID:-}" 2>/dev/null || true
    # W4OS_TEST_KEEP: the site left for a look (its logs)
    [ -z "${TMP:-}" ] || [ -n "${W4OS_TEST_KEEP:-}" ] || rm -rf "$TMP"
}

# stale TREE: what of the code the tree is older than (the plugin, the libraries it bundles, the theme), nothing when it is current
stale() {
    local tree=$1 plugin=${W4OS_PLUGIN:-$ROOT/../grav-plugin-w4os} part changed=()
    for part in w4os.php blueprints.yaml classes templates languages css js; do
        [ -e "$plugin/$part" ] || continue
        newer "$plugin/$part" "$tree/user/plugins/w4os/$part" || changed+=("plugin $part")
    done
    [ ! -d "$ROOT/../w4os-views/src" ] || newer "$ROOT/../w4os-views/src" "$tree/user/plugins/w4os/vendor/magicoli/w4os-views/src" ||
        changed+=("w4os-views")
    newer "$ROOT/theme/w4os" "$tree/user/themes/w4os" || changed+=("theme")
    [ ${#changed[@]} -eq 0 ] || echo "the Grav tree is older than the code (${changed[*]}): dev/build.sh"
}

# newer SOURCE COPY: whether COPY has every file of SOURCE as it is (COPY may have more, the files a build adds; a link of SOURCE
# that points into the built tree only is left out)
newer() {
    [ -e "$2" ] && [ -z "$(diff -rq "$1" "$2" 2>&1 | grep -v -e "^Only in $2" -e "^diff: $1/.*: No such file or directory")" ]
}

# built: whether the Grav tree is there to test, and current, the test skipped otherwise
built() {
    [ -n "${SITE:-}" ] && return
    bashunit::skip "${STALE:-no Grav tree built (dev/build.sh)}"
    return 1
}

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
