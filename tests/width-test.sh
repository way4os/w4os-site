#!/usr/bin/env bash
# The width of a page, an option of its own (its header "width", a select of the admin): full, sidebars (full width, with the
# sidebars of the home), wide (the width of the menu bar), standard (a column to read); the theme's default by template otherwise.
# End to end at the root and under a prefix: the classes of the theme each page gets.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

set_up_before_script() {
    site_set_up
    serve_prefixed
}

# body BASE PATH: the classes of the body of the page
body() {
    curl -sL "$1$2" | grep -o '<body [^>]*class="[^"]*"' | sed 's/.*class="//; s/"$//'
}

test_the_admin_gives_a_page_its_width_among_four() {
    local blueprint="$ROOT/theme/w4os/blueprints/default.yaml"
    assert_file_exists "$blueprint"
    # Quark2's page form, with the field added to it
    assert_contains 'context: theme://quark2/blueprints' "$(cat "$blueprint")"
    assert_equals "full sidebars wide standard" "$(php -r '
        require $argv[1];
        $yaml = Symfony\Component\Yaml\Yaml::parseFile($argv[2]);
        $field = $yaml["form"]["fields"]["tabs"]["fields"]["advanced"]["fields"]["columns"]["fields"]["column1"]["fields"]["header.width"];
        echo $field["type"] === "select" ? implode(" ", array_keys($field["options"])) : "";
    ' "$ROOT/build/w4os-site/grav/vendor/autoload.php" "$blueprint" 2>/dev/null)"
    assert_contains 'PAGE_WIDTH:' "$(cat "$ROOT/theme/w4os/languages.yaml")"
}

test_the_home_says_its_width_in_every_language() {
    local file
    for file in "$ROOT"/defaults/pages/01.home/*.md; do
        assert_contains 'width: sidebars' "$(cat "$file")"
        assert_not_contains 'body_classes: layout-fluid' "$(cat "$file")"
    done
}

test_each_page_has_the_width_of_its_kind_at_the_root_and_under_a_prefix() {
    built || return 0
    local base
    for base in "$URL" "$PREFIXED"; do
        # The home and its sidebars, the search full width (its list and its details side by side): Quark2's layout-fluid
        assert_matches '(^| )layout-fluid( |$)' "$(body "$base" /)"
        assert_matches '(^| )w4os-width-sidebars( |$)' "$(body "$base" /)"
        assert_matches '(^| )layout-fluid( |$)' "$(body "$base" /search)"
        assert_matches '(^| )w4os-width-full( |$)' "$(body "$base" /search)"
        # The news (a list) as wide as the menu bar, a text in its column
        assert_matches '(^| )w4os-width-wide( |$)' "$(body "$base" /news)"
        assert_not_contains 'layout-fluid' "$(body "$base" /news)"
        assert_matches '(^| )w4os-width-standard( |$)' "$(body "$base" /about)"
        assert_not_contains 'layout-fluid' "$(body "$base" /about)"
    done
}
