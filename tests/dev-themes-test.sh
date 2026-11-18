#!/usr/bin/env bash
# The themes of development (dev/themes.txt): put on a server of development by dev/deploy.sh, never in the package nor the zip
# of the site; the theme is chosen on the settings page of the admin (the w4os plugin).

set_up() {
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}

test_they_are_never_in_the_package_nor_the_zip() {
    assert_not_contains "dev/themes" "$(cat "$ROOT/packaging/build" "$ROOT/packaging/build-zip" "$ROOT/packaging/zip.sh" "$ROOT/packaging/w4os-site.yaml")"
}

test_the_deploy_of_development_puts_them_on_the_server() {
    assert_contains "dev/themes.sh" "$(cat "$ROOT/dev/deploy.sh")"
    assert_contains "dev/themes.txt" "$(cat "$ROOT/dev/themes.sh")"
}

test_no_theme_switcher_of_its_own_the_settings_of_the_site_choose_it() {
    assert_directory_not_exists "$ROOT/dev/plugins/theme-switcher"
}
