#!/usr/bin/env bash
# The home page of the site, end to end, at the root and under a prefix: what the grid is (its info, its status) in one aside, its
# message of the day and the Connect block in the other, with the news, the text in the middle (one column on a narrow screen: the
# container queries of the plugin's css/w4os.css).

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

set_up_before_script() {
    site_set_up
    serve_prefixed
}

test_the_home_page_has_what_the_grid_is_on_one_side_its_message_of_the_day_and_how_to_connect_on_the_other() {
    built || return 0
    local base home grid news
    for base in "$URL" "$PREFIXED"; do
        home=$(curl -s "$base/")
        grid=$(sed -n '/<aside class="w4os-home-grid">/,/<aside class="w4os-home-news">/p' <<<"$home")
        news=$(sed -n '/<aside class="w4os-home-news">/,$p' <<<"$home")
        assert_contains '<aside class="w4os-home-grid">' "$grid"
        assert_not_contains 'w4os-start-steps' "$grid"
        assert_contains 'w4os-start-steps' "$news"
    done
    # The theme extends the plugin's home, as w4os.org's does, rather than copying it
    assert_contains "{% extends '@w4os/w4os/home.html.twig' %}" "$(cat "$ROOT/theme/w4os/templates/w4os/home.html.twig")"
}
