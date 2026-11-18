#!/usr/bin/env bash
# An upgrade is safe with no step by hand: the pages a site made with an earlier version keep working, end to end.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

test_a_home_page_of_an_earlier_version_still_shows_with_the_blocks_around_its_text() {
    built || return 0
    # The home page as version 0.1 made it: the splash template of the w4os plugin, its text without the shortcode
    mkdir -p "$SITE/user/pages/05.old-home"
    printf '%s\n' '---' "title: 'Old home'" 'cache_enable: false' 'template: w4os/splash' '---' '# Old welcome' '' 'Some text.' \
        >"$SITE/user/pages/05.old-home/default.md"
    local status page
    status=$(curl -s -o "$TMP/old-home.html" -w '%{http_code}' "$URL/old-home")
    page=$(cat "$TMP/old-home.html")
    assert_equals 200 "$status"
    assert_contains 'class="w4os-home"' "$page"
    assert_matches '<h1[^>]*>Old welcome</h1>' "$page"
    assert_contains 'Some text.' "$page"
}
