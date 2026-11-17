#!/usr/bin/env bash
# The site as a zip (packaging/zip.sh), made of a fake Grav tree in a temporary folder: unzipped anywhere, it works as it is.

set_up() {
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    TMP=$(mktemp -d)
    # A Grav tree as the package has it: the folders where it writes are links to /var/lib and /var/cache, its .env says so
    local grav="$TMP/grav"
    mkdir -p "$grav/system" "$grav/user/themes/w4os/images" "$grav/user/plugins/w4os"
    echo '<?php' >"$grav/index.php"
    echo 'logo' >"$grav/user/plugins/w4os/logo.png"
    ln -s ../../../plugins/w4os/logo.png "$grav/user/themes/w4os/images/favicon.png"
    for dir in config pages accounts data; do ln -s "/var/lib/w4os-site/$dir" "$grav/user/$dir"; done
    for dir in assets images; do ln -s "/var/cache/w4os-site/$dir" "$grav/$dir"; done
    echo 'GRAV_CACHE_PATH=/var/cache/w4os-site/cache' >"$grav/.env"
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
    for dir in user/accounts user/data assets images cache tmp logs backup; do
        assert_directory_exists "$site/$dir"
    done
    # Nothing that points outside, nothing of a machine
    assert_empty "$(find "$TMP/unzipped" -type l)"
    assert_file_exists "$site/user/themes/w4os/images/favicon.png"
    assert_file_not_exists "$site/.env"
}
