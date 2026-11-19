# shellcheck shell=bash
# A site to test end to end, for the tests that source it: the Grav tree built (build/w4os-site/grav, or W4OS_SITE_BUILD) as the
# zip has it (site_tree), served by php alone with several workers, its engine a fake API (tests/fixtures/api.php: Ada Love, a
# resident, and God Test, a god, sign in with "secret"). Skipped when the tree is not built or older than the code (built()).

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
    # The contract of the engine the site ships, for the fake API to serve
    php -r 'require $argv[1]; echo json_encode(OpenSim\Api\Contract::document());' "$SITE/user/plugins/w4os/vendor/autoload.php" \
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
    [ -e "$2" ] && [ -z "$(LC_ALL=C diff -rq "$1" "$2" 2>&1 | grep -v -e "^Only in $2" -e "^diff: $1/.*: No such file or directory")" ]
}

# built: whether the Grav tree is there to test, and current, the test skipped otherwise
built() {
    [ -n "${SITE:-}" ] && return
    bashunit::skip "${STALE:-no Grav tree built (dev/build.sh)}"
    return 1
}

