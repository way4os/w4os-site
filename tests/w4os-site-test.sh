#!/usr/bin/env bash
# The installer, on a site in a temporary folder, with a fake engine API (tests/fixtures/api.php).

set_up_before_script() {
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    PORT=$((20000 + RANDOM % 20000))
    php -S "127.0.0.1:$PORT" "$ROOT/tests/fixtures/api.php" >/dev/null 2>&1 &
    API_PID=$!
    local tries=50
    until curl -s -o /dev/null "http://127.0.0.1:$PORT/" || [ $((tries -= 1)) -eq 0 ]; do sleep 0.1; done
}

tear_down_after_script() {
    kill "$API_PID" 2>/dev/null || true
}

set_up() {
    SITE=$(mktemp -d)
    mkdir -p "$SITE/user/data" "$SITE/cache"
    cp -R "$ROOT/defaults/config" "$SITE/user/config"
    export W4OS_SITE_ROOT="$SITE" W4OS_SITE_SHARE="$ROOT" W4OS_SITE_OWNER="$(id -un)"
}

tear_down() {
    rm -rf "$SITE"
}

site() {
    "$ROOT/bin/w4os-site" "$@" </dev/null 2>&1
}

test_version_tells_the_version_of_the_site() {
    local output
    output=$(site --version)
    assert_exit_code 0
    assert_matches '^w4os-site [^ ]+' "$output"
    assert_not_contains "unknown" "$output"
}

test_status_says_when_the_site_is_not_connected() {
    local output
    output=$(site status)
    assert_exit_code 1
    assert_contains "not connected" "$output"
}

test_setup_connects_the_site_and_keeps_the_key_out_of_the_config() {
    site setup --api "http://127.0.0.1:$PORT/api/" --url "http://127.0.0.1:$PORT/helpers/" --key osk_test >/dev/null
    assert_exit_code 0
    assert_file_contains "$SITE/user/config/plugins/w4os.yaml" "api_url: 'http://127.0.0.1:$PORT/api'"
    assert_file_contains "$SITE/user/config/plugins/w4os.yaml" "url: 'http://127.0.0.1:$PORT/helpers'"
    assert_file_contains "$SITE/user/config/plugins/w4os.yaml" "engine: 'remote'"
    assert_file_contains "$SITE/user/config/site.yaml" "title: 'Demo Grid'"
    assert_file_contains "$SITE/user/data/w4os/api.json" '"api_key":"osk_test"'
    assert_file_not_contains "$SITE/user/config/plugins/w4os.yaml" "osk_test"
    assert_contains "api:     answers" "$(site status)"
}

test_setup_needs_the_address_of_the_engine_api_never_the_helpers_api() {
    local output
    # A machine with the engine installed has its local listener, which answers
    [ ! -e /usr/share/w4os-engine ] || { bashunit::skip "the engine is installed here: its local listener answers"; return 0; }
    # Only the helpers' address: refused (no address of the engine API, or the one of the local listener when the machine has
    # opensim, which does not answer here), never their /api
    output=$(site setup --url "http://127.0.0.1:$PORT" --key osk_test)
    assert_exit_code 1
    assert_contains "engine API" "$output"
    assert_not_contains "127.0.0.1:$PORT/api" "$output"
    assert_file_contains "$SITE/user/config/plugins/w4os.yaml" "api_url: ''"
}

test_setup_refuses_a_key_the_api_refuses() {
    local output
    output=$(site setup --api "http://127.0.0.1:$PORT/api" --url "http://127.0.0.1:$PORT/helpers" --key osk_wrong)
    assert_exit_code 1
    assert_contains "does not answer" "$output"
    assert_file_contains "$SITE/user/config/plugins/w4os.yaml" "api_url: ''"
}

test_setup_keeps_a_title_with_a_quote() {
    site setup --api "http://127.0.0.1:$PORT/api" --url "http://127.0.0.1:$PORT/helpers" --key osk_test --title "Ada's grid" >/dev/null
    assert_file_contains "$SITE/user/config/site.yaml" "title: 'Ada''s grid'"
}

test_setup_no_mail_makes_a_test_site() {
    site setup --api "http://127.0.0.1:$PORT/api" --url "http://127.0.0.1:$PORT/helpers" --key osk_test --no-mail >/dev/null
    assert_file_contains "$SITE/user/config/plugins/w4os.yaml" "send_mail: false"
    assert_contains "mail:    off" "$(site status)"
    site setup --api "http://127.0.0.1:$PORT/api" --url "http://127.0.0.1:$PORT/helpers" --key osk_test --mail >/dev/null
    assert_file_contains "$SITE/user/config/plugins/w4os.yaml" "send_mail: true"
}

test_the_language_switcher_keeps_the_choice_of_the_menu() {
    # oli-langswitcher keeps the language chosen in the session (session_store_active), which the default language without
    # prefix and the language of the browser need
    assert_file_contains "$ROOT/dependencies.txt" "user/plugins/oli-langswitcher"
    assert_file_contains "$ROOT/defaults/config/system.yaml" "include_default_lang: false"
}

test_the_default_pages_link_to_registration_only_while_it_is_open() {
    # Every line of a default page that links to the registration page is inside [w4os-register]...[/w4os-register]
    local unguarded
    unguarded=$(grep -h '(/register)' "$ROOT"/defaults/pages/*/*.md | grep -v '\[w4os-register\].*(/register).*\[/w4os-register\]' || true)
    assert_empty "$unguarded"
}

test_web_apache_listens_on_its_own_port() {
    local output
    output=$(site web apache --host grid.example.org --port 8830)
    assert_contains "Listen 8830" "$output"
    assert_contains "<VirtualHost *:8830>" "$output"
    assert_contains "ServerName grid.example.org" "$output"
    assert_not_contains "{{" "$output"
}

test_the_web_configurations_route_nothing_to_the_helpers_even_on_a_machine_that_has_their_package() {
    # A machine of the grid: the helpers package and the opensim command, which prints their snippet
    mkdir -p "$SITE/helpers/public" "$SITE/bin"
    printf '#!/bin/sh\necho "AliasMatch \\"^/(?:helpers|health)(?:/.*)?$\\" \\"/usr/share/w4os-helpers/public/index.php\\""\n' >"$SITE/bin/opensim"
    chmod +x "$SITE/bin/opensim"
    local server output
    for server in apache caddy nginx; do
        output=$(PATH="$SITE/bin:$PATH" W4OS_SITE_HELPERS="$SITE/helpers" site web "$server" --host grid.example.org --port 8830)
        assert_not_contains "w4os-helpers" "$output"
        assert_not_contains "AliasMatch" "$output"
        assert_not_contains "{{" "$output"
    done
}

test_web_apache_on_port_80_adds_no_listen() {
    assert_not_contains "Listen" "$(site web apache --host grid.example.org)"
}

test_the_theme_of_the_site_shows_the_title_of_the_pages_of_the_w4os_plugin_which_leaves_it_to_the_theme() {
    local page
    page=$(cat "$ROOT/theme/w4os/templates/default.html.twig")
    assert_contains "page.header.w4os" "$page"
    assert_contains "{{ page.title }}" "$page"
    assert_contains "page.content|raw" "$page"
}

test_the_home_page_is_the_theme_s_default_page_the_blocks_of_the_grid_around_its_text() {
    local page
    for page in "$ROOT"/defaults/pages/01.home/*.md; do
        assert_contains "template: default" "$(cat "$page")"
        assert_contains "[w4os-home]" "$(cat "$page")"
        assert_not_contains "w4os/splash" "$(cat "$page")"
    done
}

test_nothing_writes_in_the_themes_of_the_package_the_logo_and_the_favicon_a_site_sets_are_its_data() {
    assert_not_contains "images/logo" "$(cat "$ROOT/packaging/w4os-site.postinst")"
    assert_not_contains "images/logo" "$(cat "$ROOT/dev/deploy.sh")"
    assert_file_not_exists "$ROOT/theme/w4os/templates/partials/logo.html.twig"
    assert_contains "custom_logo:" "$(cat "$ROOT/theme/w4os/blueprints.yaml")"
    assert_file_exists "$ROOT/theme/w4os/images/logo/opensimulator-logo.png"
}

test_the_site_gives_its_own_favicon_the_square_opensimulator_logo_as_the_theme_s_setting() {
    local icon="$ROOT/theme/w4os/images/favicon/opensimulator-logo-square.png"
    assert_file_exists "$icon"
    [ ! -L "$icon" ] || fail "the favicon is the site's own file, not a link into the plugin"
    assert_equals "PNG 512x512" "$(file -b "$icon" | sed -E 's/^PNG image data, ([0-9]+) x ([0-9]+).*/PNG \1x\2/')"
    assert_file_not_exists "$ROOT/theme/w4os/images/favicon.png"
    assert_contains "opensimulator-logo-square.png" "$(sed -n '/^custom_favicon:/,/^[a-z]/p' "$ROOT/theme/w4os/w4os.yaml")"
    # The w4os icon a site that saved its settings before still points at
    assert_file_exists "$ROOT/theme/w4os/images/favicon/cropped-w4os-logo-v1-square-32x32.png"
}

test_the_theme_has_its_picture_in_the_gallery_of_the_themes() {
    assert_equals "JPEG 500x500" "$(file -b "$ROOT/theme/w4os/thumbnail.jpg" | sed -E 's/^JPEG.*, ([0-9]+)x([0-9]+),.*/JPEG \1x\2/')"
}

test_no_theme_fix_in_the_defaults_of_a_site_the_plugin_s_code_makes_them_for_every_site() {
    assert_directory_not_exists "$ROOT/defaults/config/themes"
}
