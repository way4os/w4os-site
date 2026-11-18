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
