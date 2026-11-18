#!/usr/bin/env bash
# A visitor stays signed in: a day without a visit, a year with "remember me", the sessions out of the reach of the system's
# cleaning, the same in the zip and in the package.

set_up() {
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}

test_a_session_lasts_a_day_in_a_folder_of_the_site_that_php_alone_cleans_after_a_day() {
    local session
    session=$(sed -n '/^session:/,/^[a-z]/p' "$ROOT/defaults/config/system.yaml")
    assert_contains "timeout: 86400" "$session"
    assert_contains "save_path: user/data/sessions" "$session"
    assert_contains "gc_maxlifetime: 86400" "$session"
}

test_remember_me_lasts_a_year_checked_by_the_plugin_in_any_theme_the_avatars_kept_as_accounts_to_find_them_again() {
    assert_contains "timeout: 31536000" "$(sed -n '/^rememberme:/,/^[a-z]/p' "$ROOT/defaults/config/plugins/login.yaml")"
    # The w4os plugin checks it on the sign-in page, whatever the theme: the theme of the site has no sign-in template of its own
    assert_file_not_exists "$ROOT/theme/w4os/templates/login.html.twig"
    assert_contains "save_accounts: true" "$(cat "$ROOT/defaults/config/plugins/w4os.yaml")"
}

test_the_package_keeps_the_sessions_in_var_lib_for_the_web_server_alone() {
    assert_contains "GRAV_CONFIG=true" "$(cat "$ROOT/grav.env")"
    assert_contains "GRAV_CONFIG__system__session__options__save_path=/var/lib/w4os-site/sessions" "$(cat "$ROOT/grav.env")"
    assert_contains "install -d -o www-data -g www-data -m 700 /var/lib/w4os-site/sessions" "$(cat "$ROOT/packaging/w4os-site.postinst")"
}
