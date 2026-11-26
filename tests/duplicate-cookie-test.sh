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
    serve_other
}

tear_down_after_script() {
    pkill -P "${OTHER_PID:-0}" 2>/dev/null || true
    kill "${OTHER_PID:-}" 2>/dev/null || true
    site_tear_down
}

# serve_other: another site of its own root, the same engine, under /other on another port of the same host (a cookie knows no
# port), at OTHER
serve_other() {
    [ -n "${SITE:-}" ] || return 0
    local port=$((PORT + 2)) tries=100
    site_tree "$GRAV_TREE" "$ROOT/defaults" "$TMP/site2"
    cp "$SITE/user/config/plugins/w4os.yaml" "$TMP/site2/user/config/plugins/w4os.yaml"
    mkdir -p "$TMP/www2"
    ln -s "$TMP/site2" "$TMP/www2/other"
    (cd "$TMP/www2" && GRAV_BASEDIR=/other PHP_CLI_SERVER_WORKERS=2 exec php -S "127.0.0.1:$port" other/system/router.php \
        >/dev/null 2>&1) &
    OTHER_PID=$!
    OTHER="http://$HOST:$port/other"
    until curl -s -o /dev/null "http://127.0.0.1:$port/other/" || [ $((tries -= 1)) -eq 0 ]; do sleep 0.2; done
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

# session_setting KEY VALUE: a setting of the cookie of the session in the site's system.yaml (empty: none, Grav's or w4os's own)
session_setting() {
    local config=$SITE/user/config/system.yaml
    awk -v key="$1" -v value="$2" '$0 ~ "^  " key ": " { next } { print } /^session:$/ && value != "" { print "  " key ": " value }' \
        "$config" >"$config.new"
    mv "$config.new" "$config"
    rm -rf "$SITE/cache/compiled"
}

# session_domain DOMAIN: the domain of the cookie of the session (empty: Grav's own, the host only)
session_domain() {
    session_setting domain "$1"
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

test_a_browser_signed_in_with_the_cookie_at_the_base_of_before_stays_signed_in_with_one_cookie_at_the_root() {
    built || return 0
    local name jar=$TMP/m
    name=$(session_name)
    # Before: the cookie of the session at the base of the site (Grav's own)
    session_setting path /opensim/
    sign_in "$jar"
    assert_equals /opensim/ "$(php "$ROOT/tests/fixtures/browser.php" "$jar" paths "$name")"
    # Now: at the root of the host (w4os's), the visitor still signed in, one cookie left
    session_setting path ''
    assert_contains "task:login.logout" "$(browse "$jar" get /fr/login)"
    assert_contains "task:login.logout" "$(browse "$jar" get /fr/login)"
    assert_equals / "$(php "$ROOT/tests/fixtures/browser.php" "$jar" paths "$name")"
}

test_two_sites_of_one_host_under_two_prefixes_never_share_a_session() {
    built || return 0
    local jar=$TMP/t
    sign_in "$jar"
    assert_contains "task:login.logout" "$(browse "$jar" get /fr/login)"
    assert_not_contains "task:login.logout" \
        "$(php "$ROOT/tests/fixtures/browser.php" "$jar" get "$OTHER/fr/login" --resolve "$HOST:$((PORT + 2)):127.0.0.1" 2>/dev/null)"
    # Each its own cookie, the first site still signed in
    assert_equals 2 "$(grep -oE '"name":"grav-site-[0-9a-f]{7}"' "$jar" | sort -u | wc -l | tr -d ' ')"
    assert_contains "task:login.logout" "$(browse "$jar" get /fr/login)"
}

# declared_pages: the address of each page of the grid the site declares (Site::servedPages(), from the routes of its settings)
declared_pages() {
    php -r '
        require $argv[1]."/vendor/autoload.php";
        require $argv[1]."/user/plugins/w4os/vendor/autoload.php";
        $read = fn (string $file) => is_file($file) ? (array) Symfony\Component\Yaml\Yaml::parseFile($file) : [];
        $routes = array_replace((array) ($read($argv[1]."/user/plugins/w4os/w4os.yaml")["routes"] ?? []), (array) ($read($argv[1]."/user/config/plugins/w4os.yaml")["routes"] ?? []));
        echo implode("\n", W4OS\Grav\Site::servedPages(array_map(fn ($r) => "/".trim((string) $r, "/"), array_filter($routes)), $argv[2]));
    ' "$SITE" "$BASE"
}

test_the_language_chosen_reaches_every_page_of_the_grid_the_site_declares() {
    built || return 0
    local jar=$TMP/p url pages
    pages=$(declared_pages)
    assert_not_empty "$pages"
    landing "$jar" /en >/dev/null
    for url in $pages; do
        assert_contains '<html lang="en"' "$(php "$ROOT/tests/fixtures/browser.php" "$jar" get "$url" --resolve "$HOST:$((PORT + 1)):127.0.0.1" \
            --header 'Accept-Language: fr' --follow 2>/dev/null | tr '\n' ' ' | sed 's/<html[[:space:]]*/<html /')"
    done
}

# in_english JAR [NAME]: whether every page of the grid the site declares answers in English to a French browser, the cookie NAME
# (the session) dropped before each
in_english() {
    local url page
    for url in $(declared_pages); do
        [ -z "${2:-}" ] || php "$ROOT/tests/fixtures/browser.php" "$1" drop "$2"
        page=$(php "$ROOT/tests/fixtures/browser.php" "$1" get "$url" --resolve "$HOST:$((PORT + 1)):127.0.0.1" --header 'Accept-Language: fr' --follow 2>/dev/null)
        assert_contains '<html lang="en"' "$(tr '\n' ' ' <<<"$page" | sed 's/<html[[:space:]]*/<html /')"
    done
}

test_the_language_chosen_is_kept_without_the_session_in_the_cookie_of_the_suite() {
    built || return 0
    local name jar=$TMP/c
    name=$(session_name)
    landing "$jar" /en >/dev/null
    # The cookie of the suite, for the whole host
    assert_contains '"name":"w4os_lang","value":"en"' "$(cat "$jar")"
    assert_equals / "$(php "$ROOT/tests/fixtures/browser.php" "$jar" paths w4os_lang)"
    in_english "$jar" "$name"
}

test_the_language_chosen_is_kept_with_an_older_cookie_of_the_session_of_a_longer_path() {
    built || return 0
    local name jar=$TMP/ce
    name=$(session_name)
    php "$ROOT/tests/fixtures/browser.php" "$jar" seed "$BASE/" "$name" "$STALE" '' /opensim/fr/
    landing "$jar" /en >/dev/null
    in_english "$jar"
    assert_equals "$BASE/" "$(landing "$jar" /)"
}

test_a_lang_cookie_of_another_application_is_read_when_the_site_has_none_never_written() {
    built || return 0
    local name jar=$TMP/o
    name=$(session_name)
    php "$ROOT/tests/fixtures/browser.php" "$jar" seed "$BASE/" lang de '' /
    assert_equals "$BASE/de" "$(landing "$jar" /)"
    assert_contains '"name":"w4os_lang","value":"de"' "$(cat "$jar")"
    # One of no language of the site: the browser's; the lang cookie never written
    php "$ROOT/tests/fixtures/browser.php" "$TMP/x" seed "$BASE/" lang xx '' /
    assert_equals "$BASE/fr" "$(landing "$TMP/x" /)"
    assert_contains '"name":"lang","value":"xx"' "$(cat "$TMP/x")"
    assert_equals 1 "$(grep -o '"name":"lang"' "$TMP/x" | wc -l | tr -d ' ')"
}

test_an_older_cookie_of_a_language_path_never_keeps_the_sign_in_from_answering() {
    built || return 0
    local name jar password page out
    name=$(session_name)
    for password in wrong-on-purpose secret; do
        jar=$TMP/f-$password
        php "$ROOT/tests/fixtures/browser.php" "$jar" seed "$BASE/" "$name" "$STALE" '' /opensim/fr/
        # The form reached as a French browser reaches it: the sign-in, sent to its language
        page=$(php "$ROOT/tests/fixtures/browser.php" "$jar" get "$BASE/login" --resolve "$HOST:$((PORT + 1)):127.0.0.1" --header 'Accept-Language: fr' --follow 2>/dev/null)
        out=$(php "$ROOT/tests/fixtures/browser.php" "$jar" post "$BASE/fr/login" --resolve "$HOST:$((PORT + 1)):127.0.0.1" --header 'Accept-Language: fr' --follow \
            "username=Ada Love" "password=$password" "task=login.login" \
            "login-form-nonce=$(sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' <<<"$page" | head -1)" 2>/dev/null)
        if [ "$password" = secret ]; then
            assert_contains "task:login.logout" "$out"
        else
            assert_contains 'Échec de la connexion' "$out"
        fi
    done
}
