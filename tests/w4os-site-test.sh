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
    mkdir -p "$SITE/data" "$SITE/cache"
    cp -R "$ROOT/defaults/config" "$SITE/data/config"
    export W4OS_SITE_DATA="$SITE/data" W4OS_SITE_SHARE="$ROOT" W4OS_SITE_OWNER="$(id -un)" W4OS_SITE_CACHE="$SITE/cache"
}

tear_down() {
    rm -rf "$SITE"
}

site() {
    "$ROOT/bin/w4os-site" "$@" </dev/null 2>&1
}

test_status_says_when_the_site_is_not_connected() {
    local output
    output=$(site status)
    assert_exit_code 1
    assert_contains "not connected" "$output"
}

test_setup_connects_the_site_and_keeps_the_key_out_of_the_config() {
    site setup --url "http://127.0.0.1:$PORT/" --key osk_test >/dev/null
    assert_exit_code 0
    assert_file_contains "$SITE/data/config/plugins/w4os.yaml" "url: 'http://127.0.0.1:$PORT'"
    assert_file_contains "$SITE/data/config/site.yaml" "title: 'Demo Grid'"
    assert_file_contains "$SITE/data/data/w4os/api.json" '"api_key":"osk_test"'
    assert_file_not_contains "$SITE/data/config/plugins/w4os.yaml" "osk_test"
    assert_contains "api:     answers" "$(site status)"
}

test_setup_refuses_a_key_the_api_refuses() {
    local output
    output=$(site setup --url "http://127.0.0.1:$PORT" --key osk_wrong)
    assert_exit_code 1
    assert_contains "does not answer" "$output"
    assert_file_contains "$SITE/data/config/plugins/w4os.yaml" "url: ''"
}

test_setup_keeps_a_title_with_a_quote() {
    site setup --url "http://127.0.0.1:$PORT" --key osk_test --title "Ada's grid" >/dev/null
    assert_file_contains "$SITE/data/config/site.yaml" "title: 'Ada''s grid'"
}

test_setup_no_mail_makes_a_test_site() {
    site setup --url "http://127.0.0.1:$PORT" --key osk_test --no-mail >/dev/null
    assert_file_contains "$SITE/data/config/plugins/w4os.yaml" "send_mail: false"
    assert_contains "mail:    off" "$(site status)"
    site setup --url "http://127.0.0.1:$PORT" --key osk_test --mail >/dev/null
    assert_file_contains "$SITE/data/config/plugins/w4os.yaml" "send_mail: true"
}

test_default_languages_keep_the_choice_of_the_menu() {
    local system="$ROOT/defaults/config/system.yaml"
    assert_file_contains "$system" "include_default_lang: false"
    assert_file_contains "$system" "http_accept_language: true"
    # With the two above, the switch to the default language needs the session (oli-langswitcher, switcher_routes)
    assert_file_contains "$system" "session_store_active: true"
}

test_web_apache_listens_on_its_own_port() {
    local output
    output=$(site web apache --host grid.example.org --port 8830)
    assert_contains "Listen 8830" "$output"
    assert_contains "<VirtualHost *:8830>" "$output"
    assert_contains "ServerName grid.example.org" "$output"
    assert_not_contains "{{" "$output"
}

test_web_apache_on_port_80_adds_no_listen() {
    assert_not_contains "Listen" "$(site web apache --host grid.example.org)"
}
