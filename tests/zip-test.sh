#!/usr/bin/env bash
# The site as a zip (packaging/zip.sh), made of a fake Grav tree in a temporary folder: unzipped anywhere, it works as it is.

set_up() {
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    TMP=$(mktemp -d)
    # A Grav tree as the package builds it (a .env from an earlier build left out of the zip)
    local grav="$TMP/grav"
    mkdir -p "$grav/system" "$grav/user/themes/w4os/images" "$grav/user/plugins/w4os"
    echo '<?php' >"$grav/index.php"
    echo 'logo' >"$grav/user/plugins/w4os/logo.png"
    ln -s ../../../plugins/w4os/logo.png "$grav/user/themes/w4os/images/favicon.png"
    echo 'GRAV_CACHE_PATH=/tmp/cache' >"$grav/.env"
    # The defaults of a new site
    mkdir -p "$TMP/defaults/config/plugins" "$TMP/defaults/pages/01.home"
    echo "engine: remote" >"$TMP/defaults/config/plugins/w4os.yaml"
    echo "title: Home" >"$TMP/defaults/pages/01.home/default.md"
    # shellcheck source=../packaging/zip.sh
    source "$ROOT/packaging/zip.sh"
}

tear_down() {
    rm -rf "$TMP"
}

test_the_zip_is_the_site_ready_to_use_wherever_it_is_unzipped() {
    site_zip "$TMP/grav" "$TMP/defaults" "$TMP/dist/w4os-site_1.0.zip"
    mkdir -p "$TMP/unzipped" && unzip -q "$TMP/dist/w4os-site_1.0.zip" -d "$TMP/unzipped"
    local site="$TMP/unzipped/w4os-site"
    assert_file_exists "$site/index.php"
    # The content of a new site, and the folders where it writes, in the tree
    assert_file_contains "$site/user/config/plugins/w4os.yaml" "engine: remote"
    assert_file_exists "$site/user/pages/01.home/default.md"
    for dir in user/accounts user/data user/data/sessions assets images cache tmp logs backup; do
        assert_directory_exists "$site/$dir"
    done
    # Nothing that points outside, nothing of a machine
    assert_empty "$(find "$TMP/unzipped" -type l)"
    assert_file_exists "$site/user/themes/w4os/images/favicon.png"
    assert_file_not_exists "$site/.env"
}

test_the_zip_is_made_as_the_opensim_projects_make_theirs_by_build_tools() {
    # build-tools build zip runs packaging/build-zip, which names it dist/<project>-<version>.zip
    assert_equals 0 "$(test -x "$ROOT/packaging/build-zip"; echo $?)"
    assert_contains '"magicoli/build-tools"' "$(cat "$ROOT/composer.json")"
    assert_contains 'dist/w4os-site-$VERSION.zip' "$(cat "$ROOT/packaging/build-zip")"
    assert_not_contains "site_zip" "$(cat "$ROOT/packaging/build")"
    assert_equals 0 "$(test -x "$ROOT/dev/build.sh"; echo $?)"
}

test_the_zip_built_serves_its_pages_with_php_alone() {
    local zip
    zip=$(ls -t "$ROOT"/dist/w4os-site-*.zip 2>/dev/null | head -1)
    [ -n "$zip" ] || { bashunit::skip "no zip built (dev/build.sh zip)"; return; }
    unzip -q "$zip" -d "$TMP/served"
    assert_empty "$(find "$TMP/served" -type l)"
    assert_file_not_exists "$TMP/served/w4os-site/.env"
    local port=$((20000 + RANDOM % 20000)) tries=50
    (cd "$TMP/served/w4os-site" && exec php -S "127.0.0.1:$port" system/router.php >/dev/null 2>&1) &
    local server=$!
    until curl -s -o /dev/null "http://127.0.0.1:$port/" || [ $((tries -= 1)) -eq 0 ]; do sleep 0.2; done
    assert_equals 200 "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/")"
    assert_equals 200 "$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/user/themes/w4os/css/fontawesome/all.min.css")"
    kill "$server" 2>/dev/null || true
}

test_a_development_build_that_bundles_another_plugin_engine_or_helpers_gets_another_version() {
    mkdir -p "$TMP/a/w4os" "$TMP/b/w4os"
    echo 'engine 1' >"$TMP/a/w4os/engine.php"
    echo 'engine 2' >"$TMP/b/w4os/engine.php"
    echo "user/plugins/w4os grav-plugin-w4os-1.zip $(tree_digest "$TMP/a")" >"$TMP/a.bundled"
    echo "user/plugins/w4os grav-plugin-w4os-1.zip $(tree_digest "$TMP/b")" >"$TMP/b.bundled"
    cp "$TMP/a.bundled" "$TMP/a2.bundled"
    local a b
    a=$(bundled_version 0.1.0-dev+157.g41e480c "$TMP/a.bundled")
    b=$(bundled_version 0.1.0-dev+157.g41e480c "$TMP/b.bundled")
    assert_matches '^0\.1\.0-dev\+157\.g41e480c\.b[0-9a-f]{7}$' "$a"
    assert_not_equals "$a" "$b"
    assert_equals "$a" "$(bundled_version 0.1.0-dev+157.g41e480c "$TMP/a2.bundled")"
    # A release as it is, the releases it bundles named by its dependencies.txt
    assert_equals 1.0.0 "$(bundled_version 1.0.0 "$TMP/a.bundled")"
    assert_contains 'bundled_version "$VERSION" build/w4os-site/grav/.bundled' "$(cat "$ROOT/packaging/build-zip")"
    assert_contains '>>"$grav/.bundled"' "$(cat "$ROOT/packaging/build")"
}
