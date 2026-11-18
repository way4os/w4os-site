#!/usr/bin/env bash
# The theme switcher of development (dev/plugins/theme-switcher): the theme a visitor asks (?theme=), kept in a cookie, among the
# themes there are; never in the package nor the zip of the site.

set_up() {
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}

# The theme chosen for a query, a cookie and the themes there are (comma separated)
chosen() {
    php -r 'namespace Grav\Common { class Plugin {} } namespace { require $argv[1]; $q = $argv[2] === "-" ? null : $argv[2]; $c = $argv[3] === "-" ? null : $argv[3];
        var_export(Grav\Plugin\ThemeSwitcherPlugin::chosen($q, $c, explode(",", $argv[4]))); }' \
        "$ROOT/dev/plugins/theme-switcher/theme-switcher.php" "$@"
}

test_the_theme_asked_wins_over_the_one_kept() {
    assert_equals "'mundana'" "$(chosen mundana quark2 quark2,mundana)"
}

test_the_theme_kept_is_used_when_none_is_asked() {
    assert_equals "'mundana'" "$(chosen - mundana quark2,mundana)"
}

test_a_theme_that_is_not_there_is_ignored() {
    assert_equals "NULL" "$(chosen ../../etc - quark2,mundana)"
    assert_equals "NULL" "$(chosen - nope quark2,mundana)"
}

test_an_empty_theme_asked_goes_back_to_the_site_s_own() {
    assert_equals "''" "$(chosen '' mundana quark2,mundana)"
}

test_it_is_never_in_the_package_nor_the_zip() {
    assert_not_contains "dev/plugins" "$(cat "$ROOT/packaging/build" "$ROOT/packaging/build-zip" "$ROOT/packaging/zip.sh" "$ROOT/packaging/w4os-site.yaml")"
    assert_not_contains "dev/themes" "$(cat "$ROOT/packaging/build" "$ROOT/packaging/build-zip" "$ROOT/packaging/zip.sh" "$ROOT/packaging/w4os-site.yaml")"
}

test_the_deploy_of_development_puts_it_and_its_themes_on_the_server() {
    assert_contains "dev/plugins/theme-switcher" "$(cat "$ROOT/dev/deploy.sh")"
    assert_contains "dev/themes.txt" "$(cat "$ROOT/dev/deploy.sh")"
}

# The picker of the themes for a list of themes, the one shown and the site's own (comma separated)
picker() {
    php -r 'namespace Grav\Common { class Plugin {} } namespace { require $argv[1]; echo Grav\Plugin\ThemeSwitcherPlugin::picker(explode(",", $argv[2]), $argv[3], $argv[4]); }' \
        "$ROOT/dev/plugins/theme-switcher/theme-switcher.php" "$@"
}

test_a_picker_lists_the_themes_the_one_shown_marked_the_site_s_own_first() {
    local html
    html=$(picker quark2,mundana,w4os mundana w4os)
    assert_contains '<option value="">w4os</option>' "$html"
    assert_contains '<option value="mundana" selected>mundana</option>' "$html"
    assert_contains '<option value="quark2">quark2</option>' "$html"
    assert_not_contains '<option value="w4os"' "$html"
    assert_contains 'position:fixed' "$html"
}

test_the_picker_comes_at_the_end_of_a_page_whatever_its_theme_and_nowhere_else() {
    assert_equals '<html><body><p></p><nav>P</nav></body></html>' \
        "$(php -r 'namespace Grav\Common { class Plugin {} } namespace { require $argv[1]; echo Grav\Plugin\ThemeSwitcherPlugin::withPicker("<html><body><p></p></body></html>", "<nav>P</nav>"); }' "$ROOT/dev/plugins/theme-switcher/theme-switcher.php")"
    assert_equals '{"a":1}' \
        "$(php -r 'namespace Grav\Common { class Plugin {} } namespace { require $argv[1]; echo Grav\Plugin\ThemeSwitcherPlugin::withPicker("{\"a\":1}", "<nav>P</nav>"); }' "$ROOT/dev/plugins/theme-switcher/theme-switcher.php")"
}
