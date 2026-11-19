#!/usr/bin/env bash
# The site as a normal Grav site (bin/w4os-site-tree): a new site from the seed of the package, the site of before moved into it,
# an upgrade that replaces only what the site has as the package put it. In a temporary folder, as the package runs it.

set_up() {
    TMP=$(mktemp -d)
    export W4OS_SITE_SEED="$TMP/share/site" W4OS_SITE_ROOT="$TMP/lib/opensim/www" W4OS_SITE_OLD="$TMP/lib/w4os-site"
    export W4OS_SITE_OLD_TREE="$TMP/share/grav" W4OS_SITE_APACHE="$TMP/apache/w4os-site.conf"
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
    assert_contains "install -d -m 755 /var/lib/opensim" "$(cat "$root/packaging/w4os-site.postinst")"
    assert_not_contains "chown" "$(cat "$root/packaging/w4os-site.postinst")"
    assert_equals 'chown -R "$OWNER:$OWNER" "$ROOT"' "$(grep -o 'chown .*' "$root/bin/w4os-site-tree")"
    assert_not_contains "g+w" "$(cat "$root/bin/w4os-site-tree" "$root/packaging/w4os-site.postinst")"
    "$TREE" configure >/dev/null
    assert_equals 755 "$(stat -c %a "$(dirname "$W4OS_SITE_ROOT")" 2>/dev/null || stat -f %Lp "$(dirname "$W4OS_SITE_ROOT")")"
}
