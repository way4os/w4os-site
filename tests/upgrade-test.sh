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
    # Grav finds the new page once its cache is cleared, as after an upgrade (the package clears it)
    find "$SITE/cache" -mindepth 1 -delete 2>/dev/null || true
    local status page
    status=$(curl -s -o "$TMP/old-home.html" -w '%{http_code}' "$URL/old-home")
    page=$(cat "$TMP/old-home.html")
    assert_equals 200 "$status"
    assert_contains 'class="w4os-home"' "$page"
    assert_matches '<h1[^>]*>Old welcome</h1>' "$page"
    assert_contains 'Some text.' "$page"
}

test_the_logo_a_site_set_stays_after_an_upgrade_that_replaces_its_theme() {
    built || return 0
    # The logo the settings page put, as it puts it: the file in the site's data, the theme's own setting naming it
    mkdir -p "$SITE/user/data/theme/images/logo" "$SITE/user/config/themes"
    cp "$ROOT/theme/w4os/images/logo/opensimulator-logo.png" "$SITE/user/data/theme/images/logo/friendly-fowl-brand.png"
    printf '%s\n' 'custom_logo:' '  user/data/theme/images/logo/friendly-fowl-brand.png:' '    name: friendly-fowl-brand.png' \
        '    type: image/png' '    path: user/data/theme/images/logo/friendly-fowl-brand.png' >"$SITE/user/config/themes/quark2.yaml"
    sleep 3
    sed -i.bak -E "s/^(  theme:).*/\1 quark2/" "$SITE/user/config/system.yaml"
    # An upgrade: the theme replaced by the package's own
    rm -rf "$SITE/user/themes/quark2"
    cp -R "$GRAV_TREE/user/themes/quark2" "$SITE/user/themes/quark2"
    find "$SITE/cache" -mindepth 1 -delete 2>/dev/null || true
    assert_contains '<img src="/user/data/theme/images/logo/friendly-fowl-brand.png"' "$(curl -s -L "$URL/")"
    assert_equals 200 "$(curl -s -o /dev/null -w '%{http_code}' "$URL/user/data/theme/images/logo/friendly-fowl-brand.png")"
    sleep 3
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
}
