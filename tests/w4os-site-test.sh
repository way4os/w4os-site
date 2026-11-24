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
    # No engine of this machine, no w4os.conf of the user: nothing proposed from them, but where a test gives them
    export W4OS_SITE_ENGINE="$SITE/no-engine" HOME="$SITE/home"
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
    # Only the helpers' address, on a machine without a grid: refused (no address of the engine API), never their /api
    output=$(site setup --url "http://127.0.0.1:$PORT" --key osk_test)
    assert_exit_code 1
    assert_contains "engine API" "$output"
    assert_not_contains "127.0.0.1:$PORT/api" "$output"
    assert_file_contains "$SITE/user/config/plugins/w4os.yaml" "api_url: ''"
}

test_setup_proposes_the_engine_api_of_the_grid_of_this_machine_at_the_port_the_engine_keeps_for_it() {
    # The tree the suite runs on (W4OS_SITE_BUILD, as site.sh: the one of the PHP of this machine), else the one built here
    local built=${W4OS_SITE_BUILD:-$ROOT/build/w4os-site/grav} output
    grep -qs knownApiPort "$built/user/plugins/w4os/vendor/w4os/w4os-engine/src/Models/Grid.php" ||
        { bashunit::skip "no Grav tree built with an engine that keeps the port of a grid's API (dev/build.sh)"; return 0; }
    # A grid of this machine, the port of its engine API kept with it; the engine of this machine, the one of the tree built
    mkdir -p "$HOME/.config/w4os" "$SITE/etc/grids/fowl" "$SITE/engine/vendor"
    printf '[Defaults]\nEtcRoot = %s\n' "$SITE/etc" >"$HOME/.config/w4os/w4os.conf"
    printf '[Grid]\nApiPort = 8005\n' >"$SITE/etc/grids/fowl/fowl.conf"
    : >"$SITE/etc/grids/fowl/Robust.HG.ini"
    printf '<?php require %s; require %s;\n' "'$built/vendor/autoload.php'" "'$built/user/plugins/w4os/vendor/autoload.php'" \
        >"$SITE/engine/vendor/autoload.php"
    # Proposed and taken (nothing typed), then asked there, where nothing answers in this test
    output=$(W4OS_SITE_ENGINE="$SITE/engine" site setup --url "http://127.0.0.1:$PORT/helpers" --key osk_test)
    assert_contains "does not answer at http://127.0.0.1:8005/api" "$output"
    assert_not_contains "8780" "$output"
}

test_setup_refuses_a_key_the_api_refuses() {
    local output
    output=$(site setup --api "http://127.0.0.1:$PORT/api" --url "http://127.0.0.1:$PORT/helpers" --key osk_wrong)
    assert_exit_code 1
    assert_contains "does not answer" "$output"
    assert_file_contains "$SITE/user/config/plugins/w4os.yaml" "api_url: ''"
}

test_setup_keeps_the_title_the_site_has_over_the_ascii_name_of_its_grid() {
    printf "title: 'Kimb\xc3\xa9 R\xc3\xa8d'\n" >"$SITE/user/config/site.yaml"
    site setup --api "http://127.0.0.1:$PORT/api" --url "http://127.0.0.1:$PORT/helpers" --key osk_test >/dev/null
    assert_file_contains "$SITE/user/config/site.yaml" "title: 'Kimbé Rèd'"
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

test_the_default_pages_that_show_the_visitor_are_never_cached() {
    # A page with [getting-started] or [w4os-guest] shows the visitor's own: Grav would serve every visitor the first one's
    local page uncached=
    for page in $(grep -l -e '\[getting-started' -e '\[w4os-guest\]' "$ROOT"/defaults/pages/*/*.md); do
        sed -n '2,/^---$/p' "$page" | grep -q '^cache_enable: false$' || uncached="$uncached $page"
    done
    assert_empty "$uncached"
}

test_the_theme_has_the_components_of_a_page_as_w4os_org_has_them() {
    local css
    css=$(cat "$ROOT/theme/w4os/css/custom.css")
    assert_contains '.w4os-home-main > h2 {' "$css"
    assert_contains '.home-intro {' "$css"
    assert_contains '.tool-cards ul, .install-cards ul {' "$css"
    assert_contains '.content-item { container-type: inline-size; }' "$css"
}

test_the_texts_of_quark2_are_in_every_language_of_the_site() {
    # Quark2 has English and Spanish: the theme of the site gives each of its texts in the others
    local quark2="$ROOT/build/w4os-site/grav/user/themes/quark2/languages.yaml"
    [ -f "$quark2" ] || { bashunit::skip "the site is not built"; return; }
    assert_empty "$(php -r 'require $argv[1]; $y = "Symfony\Component\Yaml\Yaml"; $keys = function ($a, $p = "") use (&$keys) { $o = []; foreach ($a as $k => $v) { $o = array_merge($o, is_array($v) ? $keys($v, "$p$k.") : ["$p$k"]); } return $o; };
        $en = $keys($y::parseFile($argv[2])["en"]); $own = $y::parseFile($argv[3]);
        foreach (["fr", "de", "it", "nl", "pt-BR", "cy"] as $l) { foreach (array_diff($en, $keys($own[$l] ?? [])) as $k) { echo "$l $k\n"; } }' \
        "$ROOT/build/w4os-site/grav/vendor/autoload.php" "$quark2" "$ROOT/theme/w4os/languages.yaml")"
}

test_the_zip_asks_the_php_extensions_the_package_depends_on() {
    local readme extension missing=
    readme=$(grep -m1 'its extensions' "$ROOT/README.md")
    for extension in $(sed -n '/^depends:/,/^recommends:/s/^  - php-\([a-z]*\) |.*/\1/p' "$ROOT/packaging/w4os-site.yaml"); do
        [[ $readme == *"$extension"* ]] || missing="$missing $extension"
    done
    assert_empty "$missing"
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

test_web_takes_the_host_and_the_port_of_the_address_of_the_site_when_not_given() {
    local output
    output=$(site web apache)
    assert_contains "ServerName localhost" "$output"
    printf "custom_base_url: 'http://site.example.org:8830'\n" >>"$SITE/user/config/system.yaml"
    output=$(site web apache)
    assert_contains "ServerName site.example.org" "$output"
    assert_contains "Listen 8830" "$output"
    assert_contains "ServerName other.example.org" "$(site web apache --host other.example.org)"
    assert_not_contains "Listen" "$(site web apache --host other.example.org)"
}

test_web_caddy_is_a_site_block_of_its_own_to_import_next_to_other_sites() {
    mkdir -p "$SITE/webserver-configs"
    printf '# Grav\n\nlocalhost\nencode gzip\nroot * .\n@denied path_regexp ^/cache/\nroute {\n\trespond @denied 403\n\tphp_fastcgi 127.0.0.1:9000\n\tfile_server\n}\n' \
        >"$SITE/webserver-configs/Caddyfile"
    printf "custom_base_url: 'https://site.example.org'\n" >>"$SITE/user/config/system.yaml"
    local output
    output=$(W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy)
    assert_contains $'site.example.org {\n\tencode gzip' "$output"
    assert_contains "root * $SITE" "$output"
    assert_contains 'php_fastcgi unix/' "$output"
    assert_equals '}' "$(echo "$output" | tail -1)"
    assert_not_contains 'localhost' "$output"
    assert_contains $'\ngrid.example.org:8830 {' "$(W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy --host grid.example.org --port 8830)"
    printf "custom_base_url: 'http://grid.example.org:8830'\n" >>"$SITE/user/config/system.yaml"
    sed -i.bak "/custom_base_url: 'https/d" "$SITE/user/config/system.yaml"
    assert_contains $'\nhttp://grid.example.org:8830 {' "$(W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy)"
    # Caddy takes it next to another site, where it is installed
    if command -v caddy >/dev/null; then
        { echo "$output"; printf 'other.example.org {\n\trespond ok\n}\n'; } >"$SITE/Caddyfile.test"
        assert_equals 0 "$(caddy adapt --config "$SITE/Caddyfile.test" --adapter caddyfile >/dev/null 2>&1; echo $?)"
    fi
}

test_web_caddy_under_a_prefix_is_a_block_of_its_own_beside_the_host_never_its_lines() {
    mkdir -p "$SITE/webserver-configs" "$SITE/bin"
    printf '# Grav\n\nlocalhost\nencode gzip\nroot * .\n@denied path_regexp ^/cache/\nroute {\n\trespond @denied 403\n\tphp_fastcgi 127.0.0.1:9000\n\tfile_server\n}\n' \
        >"$SITE/webserver-configs/Caddyfile"
    printf "custom_base_url: 'https://kimbe.example'\n" >>"$SITE/user/config/system.yaml"
    local output
    output=$(W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy --prefix /opensim --host kimbe.example,www.kimbe.example)
    # Its own addresses, with the path: Caddy prefers them to the block of the host, which keeps whatever runs at the root
    assert_contains $'kimbe.example/opensim, www.kimbe.example/opensim {\n\tredir * /opensim/ 308\n}' "$output"
    assert_contains $'kimbe.example/opensim/*, www.kimbe.example/opensim/* {\n\tencode gzip' "$output"
    assert_contains $'\thandle_path /opensim/* {\n\t\troot * '"$SITE" "$output"
    assert_contains $'php_fastcgi unix//run/php/test.sock {\n\t\t\t\tenv SCRIPT_NAME /opensim/index.php\n\t\t\t}' "$output"
    assert_not_contains $'kimbe.example {' "$output"
    assert_not_contains 'localhost' "$output"
    # The helpers of the grid under the prefix, as opensim web gives them, before the site (no grid here: said, not invented)
    assert_contains 'no helpers of a grid of this machine under /opensim' "$output"
    printf "grid: kimbe\n" >>"$SITE/user/config/plugins/w4os.yaml"
    cat >"$SITE/bin/opensim" <<'STUB'
#!/usr/bin/env bash
case "$*" in
"web kimbe snippet caddy --prefix /opensim") printf '# Helpers of the grid kimbe.\n@opensim_helpers path /opensim/economy /opensim/economy/*\n\nhandle @opensim_helpers {\n\troot * /usr/share/w4os-helpers/public\n}\n' ;;
"web kimbe snippet caddy") printf '# Helpers of the grid kimbe.\n@opensim_helpers path /opensim/economy /opensim/economy/* /helper/query.php /helper/query.php/*\n\nhandle @opensim_helpers {\n\troot * /usr/share/w4os-helpers/public\n\tphp_fastcgi unix//run/php/php-fpm.sock\n}\n' ;;
"web kimbe paths --outside /opensim") printf '/helper/query.php\n/helper/query.php/*\n/helpers/helper/offline.php\n/helpers/helper/offline.php/*\n' ;;
*) exit 2 ;;
esac
STUB
    chmod +x "$SITE/bin/opensim"
    output=$(W4OS_SITE_OPENSIM="$SITE/bin/opensim" W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy --prefix /opensim)
    assert_contains $'kimbe.example/opensim/* {\n\tencode gzip\n\t@opensim_helpers path /opensim/economy /opensim/economy/*' "$output"
    assert_contains $'\thandle @opensim_helpers {\n\t\troot * /usr/share/w4os-helpers/public\n\t}' "$output"
    assert_not_contains '# Helpers of the grid' "$output"
    # The addresses of its helpers outside the prefix, each exactly, in a block of their own with the helpers' handler
    assert_contains $'kimbe.example/helper/query.php, kimbe.example/helper/query.php/*, kimbe.example/helpers/helper/offline.php, kimbe.example/helpers/helper/offline.php/* {\n\tencode gzip\n\troot * /usr/share/w4os-helpers/public\n\tphp_fastcgi unix//run/php/php-fpm.sock\n}' "$output"
    # A command line too old for --prefix gives the paths of the root (the whole prefix): said, never written
    printf '#!/usr/bin/env bash\nprintf "@opensim_helpers path /opensim* /health*\\n\\nhandle @opensim_helpers {\\n\\troot * /usr/share/w4os-helpers/public\\n}\\n"\n' >"$SITE/bin/opensim"
    output=$(W4OS_SITE_OPENSIM="$SITE/bin/opensim" W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy --prefix /opensim)
    assert_not_contains '@opensim_helpers' "$output"
    assert_contains 'w4os-cli 3.0.0~beta.4+125 or later' "$output"
    # Caddy takes it next to the block of the host, which it leaves as it is
    if command -v caddy >/dev/null; then
        { echo "$output"; printf 'kimbe.example {\n\trespond "root" 418\n}\n'; } >"$SITE/Caddyfile.test"
        assert_equals 0 "$(caddy adapt --config "$SITE/Caddyfile.test" --adapter caddyfile >/dev/null 2>&1; echo $?)"
    fi
}

test_web_caddy_install_writes_the_file_of_the_site_in_its_sites_never_the_file_of_the_host() {
    mkdir -p "$SITE/webserver-configs" "$SITE/caddy/sites" "$SITE/stubs"
    printf 'localhost\nencode gzip\nroot * .\nroute {\n\tphp_fastcgi 127.0.0.1:9000\n}\n' >"$SITE/webserver-configs/Caddyfile"
    printf "custom_base_url: 'https://kimbe.example'\n" >>"$SITE/user/config/system.yaml"
    printf 'kimbe.example {\n\troot * /var/www/html\n}\n' >"$SITE/caddy/sites/kimbe.example.caddyfile"
    printf '#!/usr/bin/env bash\n[ "${CADDY_REFUSES:-}" = "" ] || { echo refused; exit 1; }\n' >"$SITE/stubs/caddy"
    printf '#!/usr/bin/env bash\necho "$*" >>"%s/reloads"\n' "$SITE" >"$SITE/stubs/systemctl"
    chmod +x "$SITE/stubs/caddy" "$SITE/stubs/systemctl"
    local host_file
    host_file=$(cat "$SITE/caddy/sites/kimbe.example.caddyfile")
    # A Caddyfile that does not import its sites: said, nothing written
    printf '{\n}\n' >"$SITE/caddy/Caddyfile"
    assert_contains 'add the line import sites/*' "$(PATH="$SITE/stubs:$PATH" W4OS_SITE_CADDY_ETC="$SITE/caddy" W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy --prefix /opensim --install)"
    assert_file_not_exists "$SITE/caddy/sites/kimbe.example.w4os.caddyfile"
    printf 'import sites/*\n' >"$SITE/caddy/Caddyfile"
    PATH="$SITE/stubs:$PATH" W4OS_SITE_CADDY_ETC="$SITE/caddy" W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy --prefix /opensim --install >/dev/null
    assert_contains 'kimbe.example/opensim/* {' "$(cat "$SITE/caddy/sites/kimbe.example.w4os.caddyfile")"
    assert_equals "$host_file" "$(cat "$SITE/caddy/sites/kimbe.example.caddyfile")"
    assert_equals 'reload caddy' "$(cat "$SITE/reloads")"
    # An absolute import of the Caddyfile: the file goes where it imports
    mkdir -p "$SITE/caddy/sites-enabled"
    printf 'import %s/caddy/sites-enabled/*.caddyfile\n' "$SITE" >"$SITE/caddy/Caddyfile"
    PATH="$SITE/stubs:$PATH" W4OS_SITE_CADDY_ETC="$SITE/caddy" W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy --prefix /opensim --host http://kimbe.example --install >/dev/null
    assert_file_exists "$SITE/caddy/sites-enabled/kimbe.example.w4os.caddyfile"
    printf 'import sites/*\n' >"$SITE/caddy/Caddyfile"
    # What Caddy refuses is taken back
    rm "$SITE/caddy/sites/kimbe.example.w4os.caddyfile"
    assert_contains 'refused' "$(CADDY_REFUSES=1 PATH="$SITE/stubs:$PATH" W4OS_SITE_CADDY_ETC="$SITE/caddy" W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy --prefix /opensim --install)"
    assert_file_not_exists "$SITE/caddy/sites/kimbe.example.w4os.caddyfile"
}

test_web_runs_the_site_in_the_pool_of_the_web_user_never_in_the_one_of_the_engine_api() {
    local etc version
    etc=$(mktemp -d)
    version=$(php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')
    mkdir -p "$etc/$version/fpm/pool.d"
    # The engine API runs as the user of the grid: before www.conf by its name
    printf '%s\n' '[w4os-api]' 'user = opensim' 'listen = /run/php/w4os-api.sock' >"$etc/$version/fpm/pool.d/w4os-api.conf"
    printf '%s\n' '[www]' "user = $(id -un)" "listen = /run/php/php$version-fpm.sock" >"$etc/$version/fpm/pool.d/www.conf"
    assert_contains "proxy:unix:/run/php/php$version-fpm.sock" "$(W4OS_SITE_PHP_ETC=$etc site web apache)"
    assert_not_contains 'w4os-api.sock' "$(W4OS_SITE_PHP_ETC=$etc site web apache)"
    # The engine's alone: never the site's
    rm "$etc/$version/fpm/pool.d/www.conf"
    assert_not_contains 'w4os-api.sock' "$(W4OS_SITE_PHP_ETC=$etc site web apache)"
    rm -rf "$etc"
}

test_web_apache_hands_php_to_the_socket_its_fpm_pool_names_even_before_php_fpm_runs() {
    local etc version
    etc=$(mktemp -d)
    version=$(php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')
    mkdir -p "$etc/$version/fpm/pool.d" "$etc/7.4/fpm/pool.d"
    printf '%s\n' '[www]' 'user = www-data' "; listen = /run/php/commented.sock" "listen = /run/php/php$version-fpm.sock" >"$etc/$version/fpm/pool.d/www.conf"
    printf '%s\n' '[www]' 'listen = /run/php/php7.4-fpm.sock' >"$etc/7.4/fpm/pool.d/www.conf"
    assert_contains "SetHandler \"proxy:unix:/run/php/php$version-fpm.sock|fcgi://localhost\"" "$(W4OS_SITE_PHP_ETC=$etc site web apache)"
    # Another version only: its pool; a pool on a TCP port: no socket
    rm -r "${etc:?}/$version"
    assert_contains "proxy:unix:/run/php/php7.4-fpm.sock" "$(W4OS_SITE_PHP_ETC=$etc site web apache)"
    printf '%s\n' '[www]' 'listen = 127.0.0.1:9000' >"$etc/7.4/fpm/pool.d/www.conf"
    assert_not_contains "proxy:unix:/run/php/php7.4" "$(W4OS_SITE_PHP_ETC=$etc site web apache)"
    rm -rf "$etc"
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
