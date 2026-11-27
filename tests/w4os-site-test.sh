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

test_setup_makes_a_new_key_when_the_engine_refuses_the_one_the_site_kept() {
    mkdir -p "$SITE/user/data/w4os" "$SITE/bin"
    printf '{"api_key":"osk_old"}\n' >"$SITE/user/data/w4os/api.json"
    printf '#!/usr/bin/env bash\n[ "$1 $2" = "api-key create" ] && echo "Key osk_test made"\n' >"$SITE/bin/opensim"
    chmod +x "$SITE/bin/opensim"
    local output
    output=$(W4OS_SITE_OPENSIM="$SITE/bin/opensim" site setup --api "http://127.0.0.1:$PORT/api" --url "http://127.0.0.1:$PORT/helpers" --title Test)
    assert_contains "refuses the key the site kept" "$output"
    assert_contains "connected" "$output"
    assert_file_contains "$SITE/user/data/w4os/api.json" "osk_test"
}

test_help_of_a_command_is_its_usage() {
    local output
    output=$(site setup --help)
    assert_contains "w4os-site setup [--api <engine API>]" "$output"
    assert_contains "connect the site to the engine API" "$output"
    assert_not_contains "w4os-site web" "$output"
    assert_contains "w4os-site web apache|caddy|nginx" "$(site --help)"
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
    # Every link of a default page to the registration page is inside [w4os-register]...[/w4os-register], on its line or around
    # its lines
    local unguarded
    unguarded=$(awk '
        FNR == 1 { open = 0 }
        { line = $0; gsub(/\[w4os-register\].*\[\/w4os-register\]/, "", line) }
        line ~ /\(\/register\)/ && ! open { print FILENAME ":" FNR ": " $0 }
        line ~ /\[w4os-register\]/ { open = 1 }
        line ~ /\[\/w4os-register\]/ { open = 0 }
    ' "$ROOT"/defaults/pages/*/*.md)
    assert_empty "$unguarded"
}

test_the_default_pages_say_tu_never_vous() {
    # Tutoiement everywhere: French tu, Welsh ti (never vous, chi)
    assert_empty "$(grep -lwE 'vous|votre|vos' "$ROOT"/defaults/pages/*/*.fr.md "$ROOT"/defaults/pages/*/*/*/*/*.fr.md 2>/dev/null || true)"
    assert_empty "$(grep -lwE 'chi|eich' "$ROOT"/defaults/pages/*/*.cy.md "$ROOT"/defaults/pages/*/*/*/*/*.cy.md 2>/dev/null || true)"
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
    assert_contains '.w4os-home-main > h2, .w4os-home-main > .block {' "$css"
    assert_contains '.home-intro {' "$css"
    assert_contains '.tool-cards ul, .install-cards ul {' "$css"
    assert_contains '.content-item { container-type: inline-size; }' "$css"
}

test_a_full_width_page_is_full_width_whatever_the_version_of_quark2() {
    # Quark2 1.1.12 (Grav 1.7's) has no layout-fluid rule: the theme gives it, as Quark2 1.1.22 has it
    local css
    css=$(cat "$ROOT/theme/w4os/css/custom.css")
    assert_contains 'body.layout-fluid .container,' "$css"
    assert_contains 'body.layout-fluid #body-wrapper > .container > .content-item { max-width: none; }' "$css"
}

test_the_sections_are_apart_by_their_margins_never_by_a_line_above_their_titles() {
    local css
    css=$(cat "$ROOT/theme/w4os/css/custom.css")
    # Quark2's short line above each h2, and the line above the sections of the home page: none
    assert_contains 'h2::before { display: none; }' "$css"
    assert_not_contains 'border-top' "$(grep '.w4os-home-main' <<<"$css")"
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
    # Grav's rules in the snippet the package ships (packaging/build), imported by one line
    mkdir -p "$SITE/share/web"
    awk -f "$ROOT/packaging/grav-caddy.awk" "$SITE/webserver-configs/Caddyfile" >"$SITE/share/web/grav.caddy"
    export W4OS_SITE_SHARE="$SITE/share"
    output=$(W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy)
    assert_equals $'# The w4os site (w4os-site web caddy)\nsite.example.org {\n\tencode gzip\n\timport '"$SITE/share/web/grav.caddy $SITE"$' unix//run/php/test.sock /index.php\n}' "$output"
    assert_contains $'php_fastcgi {args.1} {\n\t\tenv SCRIPT_NAME {args.2}\n\t}' "$(cat "$SITE/share/web/grav.caddy")"
    assert_contains 'root * {args.0}' "$(cat "$SITE/share/web/grav.caddy")"
    assert_not_contains 'localhost' "$(cat "$SITE/share/web/grav.caddy")"
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
    mkdir -p "$SITE/share/web"
    awk -f "$ROOT/packaging/grav-caddy.awk" "$SITE/webserver-configs/Caddyfile" >"$SITE/share/web/grav.caddy"
    export W4OS_SITE_SHARE="$SITE/share"
    output=$(W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy --prefix /opensim --host kimbe.example,www.kimbe.example)
    # Its own addresses, with the path: Caddy prefers them to the block of the host, which keeps whatever runs at the root; no grid
    # here, no helpers
    assert_equals "# The w4os site under /opensim, beside the site of the host (w4os-site web caddy)
kimbe.example/opensim, kimbe.example/opensim/*, www.kimbe.example/opensim, www.kimbe.example/opensim/* {
	encode gzip
	redir /opensim /opensim/ 308
	# Website
	handle_path /opensim/* {
		import $SITE/share/web/grav.caddy $SITE unix//run/php/test.sock /opensim/index.php
	}
}" "$output"
    printf "grid: kimbe\n" >>"$SITE/user/config/plugins/w4os.yaml"
    cat >"$SITE/bin/opensim" <<'STUB'
#!/usr/bin/env bash
case "$*" in
"web kimbe snippet caddy --prefix /opensim --socket /run/php/test.sock") printf '# Helpers of the grid kimbe.\n@opensim_helpers path /opensim/economy /opensim/economy/*\n\nhandle @opensim_helpers {\n\troot * /usr/share/w4os-helpers/public\n}\n' ;;
"web kimbe snippet caddy --socket /run/php/test.sock") printf '# Helpers of the grid kimbe.\n@opensim_helpers path /opensim/economy /opensim/economy/* /helper/query.php /helper/query.php/*\n\nhandle @opensim_helpers {\n\troot * /usr/share/w4os-helpers/public\n\tphp_fastcgi unix//run/php/test.sock\n}\n' ;;
"web kimbe paths --outside /opensim") printf '/helper/query.php\n/helper/query.php/*\n/helpers/helper/offline.php\n/helpers/helper/offline.php/*\n/landtool.php\n' ;;
*) exit 2 ;;
esac
STUB
    chmod +x "$SITE/bin/opensim"
    output=$(W4OS_SITE_OPENSIM="$SITE/bin/opensim" W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy --prefix /opensim)
    assert_contains $'\tredir /opensim /opensim/ 308\n\t# Helpers of the grid kimbe\n\t@opensim_helpers path /opensim/economy /opensim/economy/*\n\thandle @opensim_helpers {\n\t\troot * /usr/share/w4os-helpers/public\n\t}\n\t# Website' "$output"
    # The addresses of its helpers outside the prefix, each exactly, in a block of their own with the helpers' handler
    assert_contains $'\n# Helpers of the grid kimbe at /helper\nkimbe.example/helper, kimbe.example/helper/* {\n\tencode gzip\n\troot * /usr/share/w4os-helpers/public\n\tphp_fastcgi unix//run/php/test.sock\n}' "$output"
    assert_contains $'\n# Helpers of the grid kimbe at /helpers\nkimbe.example/helpers, kimbe.example/helpers/* {' "$output"
    assert_contains $'\n# Helpers of the grid kimbe at /landtool.php\nkimbe.example/landtool.php {' "$output"
    local helpers_output=$output
    # Helpers all outside the prefix (at /helpers, the site under /opensim): their blocks all the same
    sed -i.bak 's|^"web kimbe snippet caddy --prefix /opensim --socket /run/php/test.sock").*|"web kimbe snippet caddy --prefix /opensim --socket /run/php/test.sock") printf "@opensim_helpers path \\n" ;;|' "$SITE/bin/opensim"
    output=$(W4OS_SITE_OPENSIM="$SITE/bin/opensim" W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy --prefix /opensim)
    assert_not_contains '@opensim_helpers' "$output"
    assert_contains $'\n# Helpers of the grid kimbe at /helpers\nkimbe.example/helpers, kimbe.example/helpers/* {' "$output"
    # A command line too old for --prefix gives the paths of the root (the whole prefix): said, never written
    printf '#!/usr/bin/env bash\nprintf "@opensim_helpers path /opensim* /health*\\n\\nhandle @opensim_helpers {\\n\\troot * /usr/share/w4os-helpers/public\\n}\\n"\n' >"$SITE/bin/opensim"
    output=$(W4OS_SITE_OPENSIM="$SITE/bin/opensim" W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web caddy --prefix /opensim)
    assert_not_contains '@opensim_helpers' "$output"
    assert_contains 'w4os-cli 3.0.0~beta.4+125 or later' "$output"
    assert_not_contains '# Helpers' "$output"
    # Caddy takes it next to the block of the host, which it leaves as it is
    if command -v caddy >/dev/null; then
        { echo "$helpers_output"; printf 'kimbe.example {\n\trespond "root" 418\n}\n'; } >"$SITE/Caddyfile.test"
        assert_equals 0 "$(caddy adapt --config "$SITE/Caddyfile.test" --adapter caddyfile >/dev/null 2>&1; echo $?)"
    fi
}

test_web_caddy_install_writes_the_file_of_the_site_in_its_sites_never_the_file_of_the_host() {
    mkdir -p "$SITE/webserver-configs" "$SITE/caddy/sites" "$SITE/stubs"
    printf 'localhost\nencode gzip\nroot * .\nroute {\n\tphp_fastcgi 127.0.0.1:9000\n}\n' >"$SITE/webserver-configs/Caddyfile"
    printf "custom_base_url: 'https://kimbe.example'\n" >>"$SITE/user/config/system.yaml"
    printf 'kimbe.example {\n\troot * /var/www/html\n}\n' >"$SITE/caddy/sites/kimbe.example.caddyfile"
    printf '#!/usr/bin/env bash\n[ "${CADDY_REFUSES:-}" = "" ] || { echo refused; exit 1; }\n[ "$1" != reload ] || echo "caddy reload" >>"%s/reloads"\n' "$SITE" >"$SITE/stubs/caddy"
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
    # By systemd, else the Caddy that runs (a container)
    assert_matches '^(reload caddy|caddy reload)$' "$(cat "$SITE/reloads")"
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

test_web_apache_under_a_prefix_is_included_by_the_sites_of_its_host_alone_and_taken_out_again() {
    local etc=$SITE/apache output
    mkdir -p "$etc/sites-available" "$etc/sites-enabled" "$SITE/stubs"
    # kimbe.example: an http block that only redirects, its https block in certbot's file; other.example has its own /opensim
    printf '<VirtualHost *:80>\n    ServerName kimbe.example\n    DocumentRoot /var/www/kimbe\n    RewriteEngine on\n    RewriteRule ^ https://%%{SERVER_NAME}%%{REQUEST_URI} [END,NE,R=permanent]\n</VirtualHost>\n' >"$etc/sites-available/kimbe.example.conf"
    printf '<IfModule mod_ssl.c>\n<VirtualHost *:443>\n    ServerName www.kimbe.example\n    ServerAlias kimbe.example\n    DocumentRoot /var/www/kimbe\n    SSLEngine on\n</VirtualHost>\n</IfModule>\n' >"$etc/sites-available/kimbe.example-le-ssl.conf"
    printf '<VirtualHost *:80>\n    ServerName other.example\n    Alias /opensim /var/www/other-opensim\n</VirtualHost>\n' >"$etc/sites-available/other.example.conf"
    for f in kimbe.example kimbe.example-le-ssl other.example; do ln -s "../sites-available/$f.conf" "$etc/sites-enabled/$f.conf"; done
    printf '#!/usr/bin/env bash\necho "$*" >>"%s/apache-calls"\n' "$SITE" >"$SITE/stubs/apache2ctl"
    # Its modules as Debian keeps them (mods-enabled): rewrite and alias enabled already, proxy and proxy_fcgi not
    mkdir -p "$etc/mods-enabled"
    : >"$etc/mods-enabled/rewrite.load"
    : >"$etc/mods-enabled/alias.load"
    printf '#!/usr/bin/env bash\nfor m in "$@"; do [[ $m == -* ]] || : >"%s/mods-enabled/$m.load"; done\n' "$etc" >"$SITE/stubs/a2enmod"
    printf '#!/usr/bin/env bash\nfor m in "$@"; do [[ $m == -* ]] || rm -f "%s/mods-enabled/$m.load"; done\n' "$etc" >"$SITE/stubs/a2dismod"
    chmod +x "$SITE/stubs/a2dismod"
    # A host with systemd reloads through it (ursull), a container through apache2ctl: both stubbed, either said
    cp "$SITE/stubs/apache2ctl" "$SITE/stubs/systemctl"
    chmod +x "$SITE/stubs/apache2ctl" "$SITE/stubs/a2enmod" "$SITE/stubs/systemctl"
    local before_ssl before_other
    before_ssl=$(cat "$etc/sites-available/kimbe.example-le-ssl.conf")
    before_other=$(cat "$etc/sites-available/other.example.conf")
    export W4OS_SITE_APACHE_ETC="$etc" W4OS_SITE_PHP_SOCKET=/run/php/test.sock

    # The files the question names: the one of the https block alone (the http one only redirects)
    assert_equals "$(readlink -f "$etc/sites-available/kimbe.example-le-ssl.conf")" "$(PATH="$SITE/stubs:$PATH" site web apache --host https://kimbe.example --prefix /opensim --vhosts)"
    # The modules it would enable, said before (the question names them)
    assert_equals "$(printf 'proxy\nproxy_fcgi')" "$(PATH="$SITE/stubs:$PATH" site web apache --host https://kimbe.example --prefix /opensim --modules)"
    output=$(PATH="$SITE/stubs:$PATH" site web apache --host https://kimbe.example --prefix /opensim --install)
    assert_file_exists "$etc/mods-enabled/proxy_fcgi.load"
    assert_contains "IncludeOptional $etc/w4os/kimbe.example.conf" "$(cat "$etc/sites-available/kimbe.example-le-ssl.conf")"
    assert_not_contains "IncludeOptional" "$(cat "$etc/sites-available/kimbe.example.conf")"
    assert_equals "$before_other" "$(cat "$etc/sites-available/other.example.conf")"
    assert_equals "$before_ssl" "$(cat "$etc/sites-available/kimbe.example-le-ssl.conf.before-w4os")"
    assert_contains "Alias /opensim $SITE" "$(cat "$etc/w4os/kimbe.example.conf")"
    # Once only, however often it is run
    PATH="$SITE/stubs:$PATH" site web apache --host https://kimbe.example --prefix /opensim --install >/dev/null
    assert_equals 1 "$(grep -c IncludeOptional "$etc/sites-available/kimbe.example-le-ssl.conf")"
    assert_matches "(graceful|reload apache2)" "$(cat "$SITE/apache-calls")"
    # Taken out: the files as they were, the file of the site gone
    PATH="$SITE/stubs:$PATH" site web apache --host https://kimbe.example --prefix /opensim --remove >/dev/null
    assert_equals "$before_ssl" "$(cat "$etc/sites-available/kimbe.example-le-ssl.conf")"
    assert_file_not_exists "$etc/w4os/kimbe.example.conf"
    # The modules it enabled disabled again, the ones Apache had kept
    assert_file_not_exists "$etc/mods-enabled/proxy_fcgi.load"
    assert_file_not_exists "$etc/mods-enabled/proxy.load"
    assert_file_exists "$etc/mods-enabled/rewrite.load"
    assert_file_exists "$etc/mods-enabled/alias.load"
    # No site of Apache for a host: said, nothing written
    assert_contains "no site of Apache serves nowhere.example" "$(PATH="$SITE/stubs:$PATH" site web apache --host https://nowhere.example --prefix /opensim --install)"
    assert_file_not_exists "$etc/w4os/nowhere.example.conf"
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
    # The pool of the helpers runs as the web user too: never the site's either
    printf '%s\n' '[w4os-helpers]' "user = $(id -un)" 'listen = /run/php/w4os-helpers.sock' >"$etc/$version/fpm/pool.d/w4os-helpers.conf"
    assert_contains "proxy:unix:/run/php/php$version-fpm.sock" "$(W4OS_SITE_PHP_ETC=$etc site web apache)"
    assert_not_contains 'w4os-helpers.sock' "$(W4OS_SITE_PHP_ETC=$etc site web apache)"
    rm "$etc/$version/fpm/pool.d/w4os-helpers.conf"
    # The site's own pool of the suite: taken before the host's
    printf '%s\n' '[w4os-site]' "user = $(id -un)" 'listen = /run/php/w4os-site.sock' >"$etc/$version/fpm/pool.d/w4os-site.conf"
    assert_contains 'proxy:unix:/run/php/w4os-site.sock' "$(W4OS_SITE_PHP_ETC=$etc site web apache)"
    rm "$etc/$version/fpm/pool.d/w4os-site.conf"
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

test_the_home_page_is_the_theme_s_home_page_the_blocks_of_the_grid_around_its_text() {
    local page
    # The theme's home: its default page, the width of the template home (sidebars)
    assert_contains "{% extends 'default.html.twig' %}" "$(cat "$ROOT/theme/w4os/templates/home.html.twig")"
    for page in "$ROOT"/defaults/pages/01.home/*.md; do
        assert_contains "template: home" "$(cat "$page")"
        assert_contains "[w4os-home]" "$(cat "$page")"
        assert_not_contains "w4os/splash" "$(cat "$page")"
    done
}

test_nothing_writes_in_the_themes_of_the_package_the_logo_and_the_favicon_a_site_sets_are_its_data() {
    assert_not_contains "images/logo" "$(cat "$ROOT/packaging/w4os-site.postinst")"
    assert_not_contains "images/logo" "$(cat "$ROOT/dev/deploy.sh")"
    assert_contains "custom_logo:" "$(cat "$ROOT/theme/w4os/blueprints.yaml")"
    assert_file_exists "$ROOT/theme/w4os/images/logo/opensimulator-logo.png"
}

test_without_a_logo_of_its_own_the_site_shows_its_name_never_another_logo() {
    local partial
    partial=$(cat "$ROOT/theme/w4os/templates/partials/logo.html.twig")
    # No logo given by the theme; Quark2's partial with its name in place of Grav's logo, the phone's logo the site's when it has none
    assert_not_contains "custom_logo:" "$(cat "$ROOT/theme/w4os/w4os.yaml")"
    assert_not_contains "custom_logo_mobile:" "$(cat "$ROOT/theme/w4os/w4os.yaml")"
    assert_contains '<span class="w4os-brand-name">{{ site.title }}</span>' "$partial"
    assert_not_contains "grav-logo" "$partial"
    assert_contains "theme_var('custom_logo')" "$partial"
    # The old default a site kept counts as none
    assert_contains "public const OLD_DEFAULT_LOGO = 'user/themes/w4os/images/logo/opensimulator-logo.png';" "$(cat "$ROOT/theme/w4os/w4os.php")"
    # Its name never squeezed: cut short, the site's icon below 6rem
    assert_contains "body.w4os-logo-text #header .navbar-brand::before { content: \"\"; flex: none; width: clamp(0px, (6rem - 100%) * 999, 28px)" "$(cat "$ROOT/theme/w4os/css/custom.css")"
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

test_the_cards_of_a_page_stand_on_the_solid_surface_of_the_theme() {
    # A box of the page on the theme's card colour, light or dark, over a picture behind the page too: no translucency, no blur
    local css
    css=$(cat "$ROOT/theme/w4os/css/custom.css")
    assert_contains '.tool-cards li, .install-cards li { background-color: var(--q2-bg-elev); }' "$css"
    # The surface of the boxes of the w4os plugin (what the grid is, the steps of the Connect block, the box of the search), the same
    assert_contains ':root { --w4os-surface: var(--q2-bg-elev); --w4os-accent: var(--q2-accent); }' "$css"
    # The accent of the w4os plugin (the step to do now, the row of a list chosen) the primary colour of the theme, on every page
    assert_not_contains '.w4os-start { --w4os-accent' "$css"
    assert_not_contains 'backdrop-filter' "$css"
    # The install cards in a tint of the accent, solid too
    assert_contains '.install-cards li { border-top: 3px solid var(--q2-accent); background-color: color-mix(in srgb, var(--q2-accent) 10%, var(--q2-bg-elev)); }' "$css"
    assert_not_contains 'linear-gradient(color-mix' "$css"
}

test_web_apache_keeps_the_pool_of_the_helpers_when_their_file_names_it_else_gives_them_the_one_of_the_site() {
    printf "grid: kimbe\n" >>"$SITE/user/config/plugins/w4os.yaml"
    mkdir -p "$SITE/bin"
    cat >"$SITE/bin/opensim" <<'STUB'
#!/usr/bin/env bash
[[ "$*" == "web kimbe snippet apache" ]] || exit 2
printf 'AliasMatch "^/(?:helpers)(?:/.*)?$" "/usr/share/w4os-helpers/public/index.php"\n<Directory /usr/share/w4os-helpers/public>\n\tRequire all granted\n'
[ -z "${OWN_POOL:-}" ] || printf '\t<FilesMatch "\\.php$">\n\t\tSetHandler "proxy:unix:/run/php/w4os-helpers.sock|fcgi://w4os-helpers"\n\t</FilesMatch>\n'
printf '</Directory>\n'
STUB
    chmod +x "$SITE/bin/opensim"
    local own other
    own=$(OWN_POOL=1 W4OS_SITE_OPENSIM="$SITE/bin/opensim" W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web apache --host kimbe.example --prefix /opensim)
    other=$(W4OS_SITE_OPENSIM="$SITE/bin/opensim" W4OS_SITE_PHP_SOCKET=/run/php/test.sock site web apache --host kimbe.example --prefix /opensim)
    # Their own pool, and the site's PHP for the site alone
    assert_contains 'proxy:unix:/run/php/w4os-helpers.sock' "$own"
    assert_equals 1 "$(grep -c 'proxy:unix:/run/php/test.sock' <<<"$own")"
    # A file of the helpers without it (an engine of before): the site's PHP for both
    assert_equals 2 "$(grep -c 'proxy:unix:/run/php/test.sock' <<<"$other")"
}

test_web_apache_gives_the_site_a_pool_apache_reaches_else_leaves_it_to_mod_php() {
    local etc apache stubs version reached left
    etc=$(mktemp -d) apache=$(mktemp -d) stubs=$(mktemp -d)
    version=$(php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')
    mkdir -p "$etc/$version/fpm/pool.d"
    printf '%s\n' '[www]' 'user = www-data' 'group = www-data' "listen = /run/php/php$version-fpm.sock" 'listen.owner = www-data' 'listen.group = www-data' >"$etc/$version/fpm/pool.d/www.conf"
    printf '#!/usr/bin/env bash\n[ "$1" != -M ] || echo " php_module (shared)"\n' >"$stubs/apache2ctl"
    chmod +x "$stubs/apache2ctl"
    printf 'export APACHE_RUN_USER=www-data\nexport APACHE_RUN_GROUP=www-data\n' >"$apache/envvars"
    reached=$(PATH="$stubs:$PATH" W4OS_SITE_APACHE_ETC=$apache W4OS_SITE_OWNER=www-data W4OS_SITE_PHP_ETC=$etc site web apache --host kimbe.example --prefix /opensim)
    printf 'export APACHE_RUN_USER=magic\nexport APACHE_RUN_GROUP=magic\n' >"$apache/envvars"
    left=$(PATH="$stubs:$PATH" W4OS_SITE_APACHE_ETC=$apache W4OS_SITE_OWNER=www-data W4OS_SITE_PHP_ETC=$etc site web apache --host kimbe.example --prefix /opensim)
    rm -rf "$etc" "$apache" "$stubs"
    assert_contains "proxy:unix:/run/php/php$version-fpm.sock" "$reached"
    assert_not_contains "SetHandler" "$left"
}
