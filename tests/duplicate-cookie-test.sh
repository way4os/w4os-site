#!/usr/bin/env bash
# A browser that keeps an older cookie of the name of the session beside the one of now, of other attributes (another domain, a
# longer path): a cookie of the site never replaces it, the browser sends both, the older one first. Signing in works at the first
# try all the same, and the older one goes. The site under a prefix at a host name, as a browser sees it (tests/fixtures/browser.php).

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

HOST=w4os.test
STALE=0123456789abcdef0123456789abcdef

set_up_before_script() {
    site_set_up
    serve_prefixed
    BASE="http://$HOST:$((PORT + 1))/opensim"
}

# browse JAR get|post PATH [field=value...]: the page of the site under its prefix, as the browser JAR sees it
browse() {
    local jar=$1 method=$2 path=$3
    shift 3
    php "$ROOT/tests/fixtures/browser.php" "$jar" "$method" "$BASE$path" --resolve "$HOST:$((PORT + 1)):127.0.0.1" "$@" 2>/dev/null
}

# landing JAR PATH: where a French browser lands from that page of the site (its redirections followed)
landing() {
    php "$ROOT/tests/fixtures/browser.php" "$1" get "$BASE$2" --resolve "$HOST:$((PORT + 1)):127.0.0.1" --header 'Accept-Language: fr' --follow \
        2>&1 >/dev/null | tail -1
}

# session_name: the name of the cookie of the session of the site
session_name() {
    local jar=$TMP/name
    browse "$jar" get /login >/dev/null
    grep -oE '"name":"grav-site-[^"]*"' "$jar" | head -1 | cut -d'"' -f4
}

# sign_in JAR [NONCE]: Ada Love signs in from the page of the sign-in in French, the token of that page or NONCE
sign_in() {
    local jar=$1 nonce=${2:-}
    [ -n "$nonce" ] || nonce=$(browse "$jar" get /fr/login | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    browse "$jar" post /fr/login "username=Ada Love" "password=secret" "task=login.login" "login-form-nonce=$nonce" >/dev/null
}

# session_domain DOMAIN: the domain of the cookie of the session (Grav's setting; empty: Grav's own, the host only)
session_domain() {
    local config=$SITE/user/config/system.yaml
    awk -v domain="$1" '/^  domain: / { next } { print } /^session:$/ && domain != "" { print "  domain: " domain }' "$config" >"$config.new"
    mv "$config.new" "$config"
    rm -rf "$SITE/cache/compiled"
}

test_an_older_cookie_without_the_domain_of_now_never_keeps_the_browser_from_signing_in() {
    built || return 0
    local name jar=$TMP/d
    # The cookie of now with Domain=<host> (as Grav 1.7 sets it), an older one of the host only
    session_domain "$HOST"
    name=$(session_name)
    php "$ROOT/tests/fixtures/browser.php" "$jar" seed "$BASE/" "$name" "$STALE" '' /opensim/
    sign_in "$jar"
    assert_contains "task:login.logout" "$(browse "$jar" get /fr/login)"
    # The older one gone: one cookie of the session sent
    assert_equals 1 "$(php "$ROOT/tests/fixtures/browser.php" "$jar" sent "$BASE/fr/login" "$name")"
    session_domain ''
}

test_an_older_cookie_of_a_longer_path_never_keeps_the_browser_from_signing_in_nor_locks_the_name() {
    built || return 0
    local name i jar=$TMP/e
    name=$(session_name)
    php "$ROOT/tests/fixtures/browser.php" "$jar" seed "$BASE/" "$name" "$STALE" '' /opensim/fr/
    # Forms sent again and again with the token of a page gone: said expired, never counted as failed sign-ins
    for i in 1 2 3 4 5 6; do
        sign_in "$jar" expired-token
    done
    sign_in "$jar"
    assert_contains "task:login.logout" "$(browse "$jar" get /fr/login)"
    assert_equals 1 "$(php "$ROOT/tests/fixtures/browser.php" "$jar" sent "$BASE/fr/login" "$name")"
}

test_the_language_chosen_stays_chosen_with_an_older_cookie_of_the_session() {
    built || return 0
    local name jar=$TMP/l
    session_domain "$HOST"
    name=$(session_name)
    php "$ROOT/tests/fixtures/browser.php" "$jar" seed "$BASE/" "$name" "$STALE" '' /opensim/
    # A French browser lands in French, chooses English, and stays in English on the home
    assert_equals "$BASE/fr" "$(landing "$jar" /)"
    landing "$jar" /en >/dev/null
    assert_equals "$BASE/" "$(landing "$jar" /)"
    assert_equals 1 "$(php "$ROOT/tests/fixtures/browser.php" "$jar" sent "$BASE/" "$name")"
    session_domain ''
}
