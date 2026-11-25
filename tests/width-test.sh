#!/usr/bin/env bash
# The width of a page: the theme's for its template (widths of w4os.yaml: full, sidebars, wide, standard), a page of the w4os plugin by
# its type (w4os-search...); no setting of its own. End to end at the root and under a prefix: the classes of the theme each page gets.

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

test_a_page_has_the_width_of_its_template_or_of_its_type_never_a_setting_of_its_own() {
    local config="$ROOT/theme/w4os/w4os.yaml"
    # The theme's map: the home with its sidebars, the plugin's search and map the whole width, its guide and the news wide
    assert_equals "default:standard home:sidebars blog:wide w4os-search:full w4os-map:full w4os-guide:wide" \
        "$(sed -n '/^widths:/,/^[a-z]/p' "$config" | grep -E '^  [a-z0-9-]+:' | sed -E 's/^  ([a-z0-9-]+): *([a-z]+).*/\1:\2/' | xargs)"
    assert_contains "{% extends 'default.html.twig' %}" "$(cat "$ROOT/theme/w4os/templates/home.html.twig")"
    # No field of its own in the admin, no width in a page
    assert_file_not_exists "$ROOT/theme/w4os/blueprints/default.yaml"
    assert_not_contains 'PAGE_WIDTH' "$(cat "$ROOT/theme/w4os/languages.yaml")"
    assert_empty "$(grep -rl '^width:' "$ROOT/defaults/pages" 2>/dev/null)"
    assert_not_contains 'page.header.width' "$(cat "$ROOT/theme/w4os/templates/partials/base.html.twig")"
}

test_the_home_has_the_template_home_in_every_language() {
    local file
    for file in "$ROOT"/defaults/pages/01.home/*.md; do
        assert_contains 'template: home' "$(cat "$file")"
        assert_not_contains 'width:' "$(cat "$file")"
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
