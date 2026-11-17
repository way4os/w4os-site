#!/usr/bin/env bash
# What the package bundles of a release, taken by the build (packaging/sources.sh), on a fake release in a temporary folder.

set_up() {
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    TMP=$(mktemp -d)
    # A release: what the site needs of it, and the rest
    local repo="$TMP/release"
    mkdir -p "$repo/css" "$repo/webfonts" "$repo/svgs"
    echo 'all{src:url(../webfonts/fa-solid-900.woff2)}' >"$repo/css/all.min.css"
    echo 'not this' >"$repo/css/brands.css"
    echo 'font' >"$repo/webfonts/fa-solid-900.woff2"
    echo 'license' >"$repo/LICENSE.txt"
    echo 'svg' >"$repo/svgs/x.svg"
    git -C "$repo" init -q && git -C "$repo" add -A && git -C "$repo" -c user.name=t -c user.email=t@example.org commit -qm release && git -C "$repo" tag 7.0.1
    # shellcheck source=../packaging/sources.sh
    sources="$TMP/sources" source "$ROOT/packaging/sources.sh"
}

tear_down() {
    rm -rf "$TMP"
}

test_a_release_gives_only_the_files_a_line_names_at_their_place() {
    sources="$TMP/sources" pick "file://$TMP/release" 7.0.1 "$TMP/theme/css" css/all.min.css=fontawesome/all.min.css webfonts=webfonts LICENSE.txt=fontawesome/LICENSE.txt
    assert_file_exists "$TMP/theme/css/fontawesome/all.min.css"
    assert_file_exists "$TMP/theme/css/webfonts/fa-solid-900.woff2"
    assert_file_exists "$TMP/theme/css/fontawesome/LICENSE.txt"
    assert_file_not_exists "$TMP/theme/css/fontawesome/brands.css"
    assert_directory_not_exists "$TMP/theme/css/svgs"
}

test_the_site_bundles_font_awesome_free_at_the_version_the_theme_loaded_and_loads_it_locally() {
    assert_contains "https://github.com/FortAwesome/Font-Awesome.git 7.0.1 css/all.min.css=fontawesome/all.min.css webfonts=webfonts LICENSE.txt=fontawesome/LICENSE.txt" "$(cat "$ROOT/dependencies.txt")"
    assert_contains "  local: true" "$(sed -n '/^fontawesome:/,/^[a-z]/p' "$ROOT/theme/w4os/w4os.yaml")"
}
