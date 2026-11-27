# shellcheck shell=bash
# A site to test end to end, for the tests that source it: the Grav tree built (build/w4os-site/grav, or W4OS_SITE_BUILD) as the
# zip has it (site_tree), served by php alone with several workers, its engine a fake API (tests/fixtures/api.php: Ada Love, a
# resident, and God Test, a god, sign in with "secret"). Skipped when the tree is not built or older than the code (built()).

set_up_before_script() {
    site_set_up
}

# site_set_up: the site set up and served (set_up_before_script; a test file that sets up more calls it first)
site_set_up() {
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    GRAV_TREE=${W4OS_SITE_BUILD:-$ROOT/build/w4os-site/grav}
    [ -f "$GRAV_TREE/index.php" ] || return 0
    STALE=$(stale "$GRAV_TREE")
    [ -z "$STALE" ] || return 0
    TMP=$(mktemp -d)
    # shellcheck source=../packaging/zip.sh
    source "$ROOT/packaging/zip.sh"
    # The site in the folder its prefixed address serves (serve_prefixed), SITE a link to it: every request, whichever way the server
    # routes it, has the same root, so the same name of session
    mkdir -p "$TMP/www"
    site_tree "$GRAV_TREE" "$ROOT/defaults" "$TMP/www/opensim"
    SITE="$TMP/w4os-site"
    ln -s "$TMP/www/opensim" "$SITE"
    # Its sessions at their whole path: PHP's built-in server runs some requests from the folder it serves, which a relative path
    # would be read from (a web server runs them from the site's)
    sed -i.bak -e "s#^    save_path: user/data/sessions\$#    save_path: $TMP/www/opensim/user/data/sessions#" "$SITE/user/config/system.yaml"
    rm -f "$SITE/user/config/system.yaml.bak"
    grep -q "save_path: $TMP/www/opensim/user/data/sessions" "$SITE/user/config/system.yaml" || echo "site.sh: the sessions path not set" >&2
    API_PORT=$((20000 + RANDOM % 20000))
    PORT=$((API_PORT + 1))
    # The contract of the engine the site ships, for the fake API to serve
    php -r 'require $argv[1]; echo json_encode(W4OS\Engine\Api\Contract::document());' "$SITE/user/plugins/w4os/vendor/autoload.php" \
        >"$TMP/openapi.json"
    W4OS_FAKE_OPENAPI="$TMP/openapi.json" php -S "127.0.0.1:$API_PORT" "$ROOT/tests/fixtures/api.php" >/dev/null 2>&1 &
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
    site_tear_down
}

# serve_prefixed: the same site under /opensim, as Grav's own router serves a site in a folder (GRAV_BASEDIR), at PREFIXED
serve_prefixed() {
    [ -n "${SITE:-}" ] || return 0
    local port=$((PORT + 1))
    (cd "$TMP/www" && GRAV_BASEDIR=/opensim PHP_CLI_SERVER_WORKERS=2 exec php -S "127.0.0.1:$port" opensim/system/router.php \
        >/dev/null 2>&1) &
    PREFIX_PID=$!
    PREFIXED="http://127.0.0.1:$port/opensim"
    local tries=100
    until curl -s -o /dev/null "$PREFIXED/" || [ $((tries -= 1)) -eq 0 ]; do sleep 0.2; done
}

# serve_helpers: fake helpers of the grid for the site (tests/fixtures/helpers.php), their folder HELPERS (its files delay and log),
# the blocks kept a second
serve_helpers() {
    [ -n "${SITE:-}" ] || return 0
    HELPERS=$TMP/helpers
    mkdir -p "$HELPERS"
    local port=$((API_PORT + 3))
    W4OS_HELPERS=$HELPERS php "$ROOT/tests/fixtures/helpers.php" "$port" >/dev/null 2>&1 &
    HELPERS_PID=$!
    sed -i.bak -e "/^url:/d" -e "/^cache:/d" "$SITE/user/config/plugins/w4os.yaml" && rm -f "$SITE/user/config/plugins/w4os.yaml.bak"
    printf "url: 'http://127.0.0.1:%s/helpers'\ncache: 1\n" "$port" >>"$SITE/user/config/plugins/w4os.yaml"
    local tries=100
    until curl -s -o /dev/null "http://127.0.0.1:$port/" || [ $((tries -= 1)) -eq 0 ]; do sleep 0.2; done
}

# serve_fastcgi: the same site served by Caddy and PHP-FPM, as a web server serves it (the page sent before the end of the
# request), at FASTCGI; nothing without them
serve_fastcgi() {
    [ -n "${SITE:-}" ] || return 0
    local fpm port=$((API_PORT + 4))
    fpm=$(command -v php-fpm || find /usr/local/sbin /usr/sbin -name 'php-fpm*' 2>/dev/null | sort | tail -1)
    [ -n "$fpm" ] && command -v caddy >/dev/null || return 0
    printf '[global]\nerror_log = %s\ndaemonize = no\n[site]\nlisten = %s\npm = static\npm.max_children = 4\n' \
        "$TMP/fpm.log" "$TMP/fpm.sock" >"$TMP/fpm.conf"
    "$fpm" -y "$TMP/fpm.conf" >/dev/null 2>&1 &
    FPM_PID=$!
    printf '{\n\tadmin off\n\tauto_https off\n}\nhttp://127.0.0.1:%s {\n\troot * %s\n\tphp_fastcgi unix/%s\n\tfile_server\n}\n' \
        "$port" "$TMP/www/opensim" "$TMP/fpm.sock" >"$TMP/Caddyfile"
    XDG_DATA_HOME=$TMP/caddy XDG_CONFIG_HOME=$TMP/caddy caddy run --config "$TMP/Caddyfile" --adapter caddyfile >"$TMP/caddy.log" 2>&1 &
    CADDY_PID=$!
    FASTCGI="http://127.0.0.1:$port"
    local tries=100
    until [ "$(curl -s -o /dev/null -w '%{http_code}' "$FASTCGI/")" = 200 ] || [ $((tries -= 1)) -eq 0 ]; do sleep 0.2; done
}

# site_tear_down: the servers stopped, the site removed (tear_down_after_script)
site_tear_down() {
    kill "${CADDY_PID:-}" "${FPM_PID:-}" 2>/dev/null || true
    kill "${HELPERS_PID:-}" 2>/dev/null || true
    pkill -P "${PREFIX_PID:-0}" 2>/dev/null || true
    kill "${PREFIX_PID:-}" 2>/dev/null || true
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
    [ ! -d "$ROOT/../w4os-views/src" ] || newer "$ROOT/../w4os-views/src" "$tree/user/plugins/w4os/vendor/w4os/w4os-views/src" ||
        changed+=("w4os-views")
    newer "$ROOT/theme/w4os" "$tree/user/themes/w4os" || changed+=("theme")
    [ ${#changed[@]} -eq 0 ] || echo "the Grav tree is older than the code (${changed[*]}): dev/build.sh"
}

# newer SOURCE COPY: whether COPY has every file of SOURCE as it is (COPY may have more, the files a build adds; a link of SOURCE
# that points into the built tree only is left out)
newer() {
    [ -e "$2" ] && [ -z "$(LC_ALL=C diff -rq "$1" "$2" 2>&1 | grep -v -e "^Only in $2" -e "^diff: $1/.*: No such file or directory")" ]
}

# built: whether the Grav tree is there to test, and current, the test skipped otherwise
built() {
    [ -n "${SITE:-}" ] && return
    bashunit::skip "${STALE:-no Grav tree built (dev/build.sh)}"
    return 1
}

