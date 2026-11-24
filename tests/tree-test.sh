#!/usr/bin/env bash
# The site as a normal Grav site (bin/w4os-site-tree): a new site from the seed of the package, the site of before moved into it,
# an upgrade that replaces only what the site has as the package put it. In a temporary folder, as the package runs it.

set_up() {
    TMP=$(mktemp -d)
    export W4OS_SITE_SEED="$TMP/share/site" W4OS_SITE_ROOT="$TMP/lib/w4os/www" W4OS_SITE_OLD="$TMP/lib/w4os-site"
    export W4OS_SITE_PREVIOUS="$TMP/lib/opensim/www"
    export W4OS_SITE_OLD_TREE="$TMP/share/grav" W4OS_SITE_APACHE="$TMP/apache/w4os-site.conf"
    export W4OS_SITE_LEGACY="$TMP/share/site-grav17"
    TREE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/w4os-site-tree"
    seed 1
}

tear_down() {
    rm -rf "$TMP"
}

# seed VERSION: the site the package ships, at a version
seed() {
    local s=$W4OS_SITE_SEED
    rm -rf "$s"
    mkdir -p "$s/system" "$s/user/plugins/w4os" "$s/user/plugins/login" "$s/user/themes/w4os" "$s/user/config" "$s/user/pages/01.home"
    echo "<?php // grav $1" >"$s/index.php"
    echo "grav $1" >"$s/system/defines.php"
    echo "rewrite" >"$s/.htaccess"
    echo "w4os $1" >"$s/user/plugins/w4os/w4os.php"
    echo "login 1" >"$s/user/plugins/login/login.php"
    echo "theme 1" >"$s/user/themes/w4os/theme.css"
    [ "$1" = 1 ] && echo "old" >"$s/user/plugins/w4os/gone.php"
    echo "title: 'My grid'" >"$s/user/config/site.yaml"
    echo "# Home" >"$s/user/pages/01.home/default.md"
}

# legacy: the units the package ships for PHP older than 8.3: Grav 1.7, a Quark 2 for it (a file of its own the other has not)
legacy() {
    local l=$W4OS_SITE_LEGACY
    mkdir -p "$l/system" "$l/user/themes/quark2" "$W4OS_SITE_SEED/user/themes/quark2"
    echo "<?php // grav 1.7" >"$l/index.php"
    echo "grav 1.7" >"$l/system/defines.php"
    echo "grav 1.7 alone" >"$l/system/only17.php"
    echo "quark2 1.1.12" >"$l/user/themes/quark2/quark2.php"
    echo "quark2 1.1.22" >"$W4OS_SITE_SEED/user/themes/quark2/quark2.php"
}

# php VERSION_ID VERSION: the PHP of the site, at a version
php_at() {
    printf '#!/bin/sh\ncase "$2" in *VERSION_ID*) echo %s ;; *) echo %s ;; esac\n' "$1" "$2" >"$TMP/php"
    chmod +x "$TMP/php"
    export W4OS_SITE_PHP="$TMP/php"
}

test_a_new_site_is_the_seed_where_it_is_served_with_what_the_package_put() {
    "$TREE" configure >/dev/null
    assert_file_exists "$W4OS_SITE_ROOT/index.php"
    assert_equals "title: 'My grid'" "$(cat "$W4OS_SITE_ROOT/user/config/site.yaml")"
    assert_contains "user/plugins/w4os/w4os.php" "$(cat "$W4OS_SITE_ROOT/user/data/w4os-site/manifest")"
    assert_not_contains "user/config" "$(cat "$W4OS_SITE_ROOT/user/data/w4os-site/manifest")"
}

test_the_site_of_before_moves_into_the_new_one_its_content_its_additions_its_apache_configuration() {
    mkdir -p "$W4OS_SITE_OLD/config" "$W4OS_SITE_OLD/data/w4os" "$W4OS_SITE_OLD/sessions" "$W4OS_SITE_OLD/pages/02.news" \
        "$W4OS_SITE_OLD_TREE/user/plugins/admin2" "$W4OS_SITE_OLD_TREE/user/plugins/w4os" "$(dirname "$W4OS_SITE_APACHE")"
    echo "title: 'Friendly Fowl'" >"$W4OS_SITE_OLD/config/site.yaml"
    echo '{"api_key":"osk_test"}' >"$W4OS_SITE_OLD/data/w4os/api.json"
    echo "session" >"$W4OS_SITE_OLD/sessions/sess_1"
    echo "# News" >"$W4OS_SITE_OLD/pages/02.news/default.md"
    echo "admin2" >"$W4OS_SITE_OLD_TREE/user/plugins/admin2/admin2.php"
    echo "w4os 0" >"$W4OS_SITE_OLD_TREE/user/plugins/w4os/w4os.php"
    printf '%s\n' '# The w4os site (fowl.example), made by w4os-site web apache.' '<VirtualHost *:80>' \
        '    DocumentRoot /usr/share/w4os-site/grav' '    <Directory /usr/share/w4os-site/grav>' '    </Directory>' \
        '    <Directory /var/cache/w4os-site>' '        Require all granted' '    </Directory>' '</VirtualHost>' >"$W4OS_SITE_APACHE"
    local out
    out=$("$TREE" configure)
    assert_equals "title: 'Friendly Fowl'" "$(cat "$W4OS_SITE_ROOT/user/config/site.yaml")"
    assert_file_exists "$W4OS_SITE_ROOT/user/data/w4os/api.json"
    assert_file_exists "$W4OS_SITE_ROOT/user/pages/02.news/default.md"
    assert_file_exists "$W4OS_SITE_ROOT/user/data/sessions/sess_1"
    # Added with GPM before: kept; the package's own: the new one
    assert_file_exists "$W4OS_SITE_ROOT/user/plugins/admin2/admin2.php"
    assert_equals "w4os 1" "$(cat "$W4OS_SITE_ROOT/user/plugins/w4os/w4os.php")"
    assert_contains "user/plugins/admin2, added to the site of before, kept" "$out"
    # The folders of before kept aside, the manifest the package's
    assert_directory_exists "$W4OS_SITE_OLD.migrated"
    assert_file_exists "$W4OS_SITE_OLD.migrated/grav/user/plugins/admin2/admin2.php"
    assert_contains "user/plugins/w4os/w4os.php" "$(cat "$W4OS_SITE_ROOT/user/data/w4os-site/manifest")"
    assert_contains "DocumentRoot $W4OS_SITE_ROOT" "$(cat "$W4OS_SITE_APACHE")"
    assert_not_contains "/var/cache/w4os-site" "$(cat "$W4OS_SITE_APACHE")"
    # Done once
    assert_not_contains "moved" "$("$TREE" configure)"
}

test_the_site_in_the_folder_of_before_moves_to_its_folder_a_link_left_where_it_was() {
    "$TREE" configure >/dev/null
    mkdir -p "$(dirname "$W4OS_SITE_PREVIOUS")" "$(dirname "$W4OS_SITE_APACHE")"
    mv "$W4OS_SITE_ROOT" "$W4OS_SITE_PREVIOUS"
    echo "site: mine" >"$W4OS_SITE_PREVIOUS/user/config/site.yaml"
    printf '%s\n' '# The w4os site, written by w4os-site web' '<VirtualHost *:80>' "    DocumentRoot $W4OS_SITE_PREVIOUS" \
        "    <Directory $W4OS_SITE_PREVIOUS>" '    </Directory>' '</VirtualHost>' >"$W4OS_SITE_APACHE"
    seed 2

    output=$("$TREE" configure)

    assert_equals "site: mine" "$(cat "$W4OS_SITE_ROOT/user/config/site.yaml")"
    assert_equals "w4os 2" "$(cat "$W4OS_SITE_ROOT/user/plugins/w4os/w4os.php")"
    assert_equals "$W4OS_SITE_ROOT" "$(readlink "$W4OS_SITE_PREVIOUS")"
    assert_contains "DocumentRoot $W4OS_SITE_ROOT" "$(cat "$W4OS_SITE_APACHE")"
    assert_not_contains "$W4OS_SITE_PREVIOUS" "$(cat "$W4OS_SITE_APACHE")"
    assert_contains "the site is now in $W4OS_SITE_ROOT" "$output"
    # Once moved, an upgrade leaves the link as it is
    "$TREE" configure >/dev/null
    assert_equals "$W4OS_SITE_ROOT" "$(readlink "$W4OS_SITE_PREVIOUS")"
}

test_an_upgrade_replaces_only_what_the_site_has_as_the_package_put_it() {
    "$TREE" configure >/dev/null
    # The site's own: a theme changed by hand, a logo copied into it, a plugin updated with GPM, a plugin removed
    echo "theme mine" >"$W4OS_SITE_ROOT/user/themes/w4os/theme.css"
    mkdir -p "$W4OS_SITE_ROOT/user/themes/w4os/images/logo"
    echo "logo" >"$W4OS_SITE_ROOT/user/themes/w4os/images/logo/site-logo.png"
    rm -rf "$W4OS_SITE_ROOT/user/plugins/login"
    echo "site: mine" >"$W4OS_SITE_ROOT/user/config/site.yaml"
    seed 2
    echo "theme 2" >"$W4OS_SITE_SEED/user/themes/w4os/theme.css"
    mkdir -p "$W4OS_SITE_SEED/user/plugins/shortcode-core" && echo "new" >"$W4OS_SITE_SEED/user/plugins/shortcode-core/sc.php"
    local out
    out=$("$TREE" configure)
    # Grav and the plugin as the package put them: the new ones, a file the new one has no more gone
    assert_equals "grav 2" "$(cat "$W4OS_SITE_ROOT/system/defines.php")"
    assert_equals "w4os 2" "$(cat "$W4OS_SITE_ROOT/user/plugins/w4os/w4os.php")"
    assert_file_not_exists "$W4OS_SITE_ROOT/user/plugins/w4os/gone.php"
    # The theme changed on the site: as it is, said; the logo the site put in it, its config
    assert_equals "theme mine" "$(cat "$W4OS_SITE_ROOT/user/themes/w4os/theme.css")"
    assert_contains "themes/w4os changed on this site, left as it is" "$out"
    assert_file_exists "$W4OS_SITE_ROOT/user/themes/w4os/images/logo/site-logo.png"
    assert_equals "site: mine" "$(cat "$W4OS_SITE_ROOT/user/config/site.yaml")"
    # A plugin the site removed stays out; a new one of the package comes in
    assert_file_not_exists "$W4OS_SITE_ROOT/user/plugins/login/login.php"
    assert_contains "plugins/login removed from this site, left out" "$out"
    assert_file_exists "$W4OS_SITE_ROOT/user/plugins/shortcode-core/sc.php"
    # Changed once, still changed at the next upgrade
    assert_contains "themes/w4os changed on this site, left as it is" "$("$TREE" configure)"
}

test_the_web_user_writes_only_its_own_tree_never_what_opensim_owns() {
    local root
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    # The home of the suite made 755 when missing, never given to the web user; the web user gets the site's tree alone
    assert_contains "install -d -m 755 /var/lib/w4os" "$(cat "$root/packaging/w4os-site.postinst")"
    assert_not_contains "chown" "$(cat "$root/packaging/w4os-site.postinst")"
    assert_equals 'chown -R "$OWNER:$GROUP" "$ROOT"' "$(grep -o 'chown .*' "$root/bin/w4os-site-tree")"
    assert_not_contains "g+w" "$(cat "$root/bin/w4os-site-tree" "$root/packaging/w4os-site.postinst")"
    "$TREE" configure >/dev/null
    assert_equals 755 "$(stat -c %a "$(dirname "$W4OS_SITE_ROOT")" 2>/dev/null || stat -f %Lp "$(dirname "$W4OS_SITE_ROOT")")"
}

test_php_older_than_8_3_gets_grav_1_7_and_its_quark_2_then_grav_2_once_php_is_newer() {
    legacy
    php_at 80236 8.2.36
    local out
    out=$("$TREE" configure)
    assert_contains "PHP 8.2.36: Grav 1.7 (Grav 2 needs PHP 8.3)" "$out"
    assert_equals "grav 1.7" "$(cat "$W4OS_SITE_ROOT/system/defines.php")"
    assert_equals "quark2 1.1.12" "$(cat "$W4OS_SITE_ROOT/user/themes/quark2/quark2.php")"
    # The rest of the seed as on any PHP
    assert_equals "w4os 1" "$(cat "$W4OS_SITE_ROOT/user/plugins/w4os/w4os.php")"
    assert_equals "title: 'My grid'" "$(cat "$W4OS_SITE_ROOT/user/config/site.yaml")"
    # Upgraded on the same PHP: still Grav 1.7, as put
    seed 2
    legacy
    "$TREE" configure >/dev/null
    assert_equals "grav 1.7" "$(cat "$W4OS_SITE_ROOT/system/defines.php")"
    assert_equals "w4os 2" "$(cat "$W4OS_SITE_ROOT/user/plugins/w4os/w4os.php")"
    # PHP 8.4 (Debian 13): Grav 2 and its Quark 2, what Grav 1.7 had alone gone
    php_at 80428 8.4.28
    out=$("$TREE" configure)
    assert_not_contains "Grav 1.7" "$out"
    assert_equals "grav 2" "$(cat "$W4OS_SITE_ROOT/system/defines.php")"
    assert_equals "quark2 1.1.22" "$(cat "$W4OS_SITE_ROOT/user/themes/quark2/quark2.php")"
    assert_file_not_exists "$W4OS_SITE_ROOT/system/only17.php"
}

test_a_package_without_the_units_for_old_php_keeps_the_seed_whatever_the_php() {
    php_at 80236 8.2.36
    "$TREE" configure >/dev/null
    assert_equals "grav 1" "$(cat "$W4OS_SITE_ROOT/system/defines.php")"
}

test_the_site_belongs_to_the_web_account_the_engine_resolves_www_data_without_one() {
    local built home
    built="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/build/w4os-site/grav"
    # Nothing to read it with (no plugin, so no engine): www-data
    assert_equals "www-data www-data" "$(bash -c 'source "$1"; web_account' _ "$TREE")"
    if [ ! -f "$built/user/plugins/w4os/vendor/autoload.php" ]; then
        bashunit::skip "no Grav tree built (dev/build.sh), whose w4os plugin carries the engine"
        return
    fi
    # The engine's own reading of w4os.conf: the profile over [Defaults]
    home=$(mktemp -d)
    mkdir -p "$home/.config/w4os"
    printf '%s\n' '[Defaults]' 'WebUser = www-data' 'WebGroup = www-data' 'DefaultProfile = mine' '' '[mine]' 'WebUser = siteweb' \
        'WebGroup = webgrp' >"$home/.config/w4os/w4os.conf"
    assert_equals "siteweb webgrp" "$(HOME=$home W4OS_SITE_ROOT=$built bash -c 'source "$1"; web_account' _ "$TREE")"
    rm -rf "$home"
}

# page FOLDER TEXT: a default page of the seed
page() {
    mkdir -p "$W4OS_SITE_SEED/user/pages/$1"
    echo "$2" >"$W4OS_SITE_SEED/user/pages/$1/default.md"
}

test_the_default_pages_are_units_added_updated_while_untouched_never_changed_back_never_brought_back() {
    page 02.help "help 1"
    page 03.news "news 1"
    page 05.contact "contact 1"
    "$TREE" configure >/dev/null
    assert_contains "user/pages/02.help/default.md" "$(cat "$W4OS_SITE_ROOT/user/data/w4os-site/manifest")"
    # The site's own: news changed, contact removed, a picture added to help
    echo "my news" >"$W4OS_SITE_ROOT/user/pages/03.news/default.md"
    rm -rf "$W4OS_SITE_ROOT/user/pages/05.contact"
    echo "png" >"$W4OS_SITE_ROOT/user/pages/02.help/picture.png"
    page 02.help "help 2"
    page 03.news "news 2"
    page 05.contact "contact 2"
    page 04.about "about 1"
    local out
    out=$("$TREE" configure)
    # Untouched: the new text, the site's picture kept; new: added; changed: as it is, said; removed: left out
    assert_equals "help 2" "$(cat "$W4OS_SITE_ROOT/user/pages/02.help/default.md")"
    assert_file_exists "$W4OS_SITE_ROOT/user/pages/02.help/picture.png"
    assert_equals "about 1" "$(cat "$W4OS_SITE_ROOT/user/pages/04.about/default.md")"
    assert_contains "pages/04.about added" "$out"
    assert_equals "my news" "$(cat "$W4OS_SITE_ROOT/user/pages/03.news/default.md")"
    assert_contains "pages/03.news changed on this site, left as it is" "$out"
    assert_directory_not_exists "$W4OS_SITE_ROOT/user/pages/05.contact"
    assert_contains "pages/05.contact removed from this site, left out" "$out"
}

test_a_new_default_page_never_doubles_a_page_the_site_has_at_its_route() {
    "$TREE" configure >/dev/null
    mkdir -p "$W4OS_SITE_ROOT/user/pages/07.about"
    echo "ours" >"$W4OS_SITE_ROOT/user/pages/07.about/default.md"
    page 04.about "about 1"
    local out
    out=$("$TREE" configure)
    assert_directory_not_exists "$W4OS_SITE_ROOT/user/pages/04.about"
    assert_equals "ours" "$(cat "$W4OS_SITE_ROOT/user/pages/07.about/default.md")"
    assert_contains "pages/04.about: the site has its own page at /about, left out" "$out"
}

test_a_site_of_before_the_pages_were_units_gets_the_new_text_of_a_page_it_has_as_a_version_of_the_package_gave_it() {
    page 02.help "help 1"
    page 03.news "news 1"
    "$TREE" configure >/dev/null
    # A manifest of before: no page in it
    sed -i.bak '/user\/pages\//d' "$W4OS_SITE_ROOT/user/data/w4os-site/manifest" && rm -f "$W4OS_SITE_ROOT/user/data/w4os-site/manifest.bak"
    echo "my news" >"$W4OS_SITE_ROOT/user/pages/03.news/default.md"
    # The texts the package gave each page in its versions (the build reads them in git)
    export W4OS_SITE_PAGES_HISTORY="$TMP/share/pages-history"
    printf 'user/pages/02.help/default.md\t%s\nuser/pages/03.news/default.md\t%s\n' "$(php -r 'echo md5("help 1\n");')" \
        "$(php -r 'echo md5("news 1\n");')" >"$W4OS_SITE_PAGES_HISTORY"
    page 02.help "help 2"
    page 03.news "news 2"
    local out
    out=$("$TREE" configure)
    assert_equals "help 2" "$(cat "$W4OS_SITE_ROOT/user/pages/02.help/default.md")"
    assert_equals "my news" "$(cat "$W4OS_SITE_ROOT/user/pages/03.news/default.md")"
    assert_contains "pages/03.news changed on this site, left as it is" "$out"
}
