#!/usr/bin/env bash
# The menu of the site, end to end, the same under every theme (the pages of Grav's tree, the w4os plugin's among them): Search;
# My avatar to /profile, Edit profile and Logout under it once signed in; Admin for a god, the settings under it. /profile: the
# profile of the avatar signed in, the registration for a visitor.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

# home THEME JAR: the home page under a theme, as the browser JAR sees it. Grav tells a change of its settings by the time of the
# file, to the second (the theme changed a second after it last read them), and each worker of the server keeps the settings it
# compiled for up to two seconds (opcache.revalidate_freq): the page asked two seconds after the change
home() {
    sleep 1
    sed -i.bak -E "s/^(  theme:).*/\1 $1/" "$SITE/user/config/system.yaml"
    sleep 2
    curl -s -L -b "$2" "$URL/"
}

test_the_menu_is_the_same_under_themes_of_other_structures() {
    built || return 0
    cp -R "$ROOT/build/dev/user/themes/." "$SITE/user/themes/" 2>/dev/null || true
    : >"$TMP/anon"
    sign_in_as "$TMP/ada" "Ada Love"
    sign_in_as "$TMP/god" "God Test"
    local theme page
    for theme in quark2 editorial; do
        [ -d "$SITE/user/themes/$theme" ] || continue
        page=$(home "$theme" "$TMP/anon")
        assert_contains 'href="/profile"' "$page"
        assert_not_contains 'href="/account"' "$page"
        # Signing in and creating an avatar, under my avatar
        assert_contains 'href="/login"' "$page"
        assert_contains 'href="/register"' "$page"
        page=$(home "$theme" "$TMP/ada")
        assert_contains 'href="/profile"' "$page"
        assert_contains 'href="/account"' "$page"
        assert_contains 'href="/account/logout"' "$page"
        assert_not_contains 'href="/w4os"' "$page"
        page=$(home "$theme" "$TMP/god")
        assert_contains 'href="/w4os"' "$page"
        assert_contains 'href="/w4os/settings"' "$page"
    done
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
}

test_the_w4os_theme_has_the_menus_of_the_visitor_in_its_top_bar_the_search_at_the_end_of_the_main_menu() {
    built || return 0
    sign_in_as "$TMP/god7" "God Test"
    local page navigation
    page=$(home w4os "$TMP/anon7")
    navigation=$(echo "$page" | sed -n '/<ul class="navigation">/,/<\/ul>/p' | head -40)
    assert_contains 'href="/search"' "$navigation"
    assert_not_contains 'href="/profile"' "$navigation"
    assert_contains 'class="w4os-visitor-menus"' "$page"
    assert_contains 'class="w4os-visitor-menus w4os-menus-open"' "$page"
    assert_contains 'href="/register"' "$page"
    page=$(home w4os "$TMP/god7")
    # The admin, then the avatar, always last
    assert_contains 'w4os-admin-menu' "$page"
    assert_contains 'login.logout' "$page"
    [ "$(echo "$page" | grep -o 'w4os-admin-menu\|login\.logout' | head -2 | tr '\n' ' ')" = 'w4os-admin-menu login.logout ' ] || fail "the admin menu is not before the avatar's"
}

test_my_avatar_is_the_profile_of_the_avatar_signed_in_and_the_registration_for_a_visitor() {
    built || return 0
    sign_in_as "$TMP/ada2" "Ada Love"
    assert_equals 302 "$(curl -s -o /dev/null -w '%{http_code}' "$URL/profile")"
    assert_contains "/register" "$(curl -s -o /dev/null -w '%{redirect_url}' "$URL/profile")"
    assert_contains "<title>Ada Love" "$(curl -s -b "$TMP/ada2" "$URL/profile")"
    # The other way: the registration of a visitor, the profile of the avatar signed in
    assert_equals 200 "$(curl -s -o /dev/null -w '%{http_code}' "$URL/register")"
    assert_equals "302 $URL/profile" "$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -b "$TMP/ada2" "$URL/register")"
}

test_logout_signs_out_as_the_login_plugin_does() {
    built || return 0
    sign_in_as "$TMP/ada3" "Ada Love"
    assert_contains "login.logout" "$(curl -s -o /dev/null -w '%{redirect_url}' -b "$TMP/ada3" "$URL/account/logout")"
}

test_the_admin_pages_have_their_own_route_the_old_addresses_lead_there() {
    built || return 0
    sign_in_as "$TMP/god6" "God Test"
    local old new got
    for old in dashboard:/w4os avatars:/w4os/avatars avatars/edit:/w4os/avatars/edit regions:/w4os/regions \
        regions/region:/w4os/regions/region simulators:/w4os/simulators settings:/w4os/settings; do
        new=${old#*:}; old=${old%%:*}
        got=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -b "$TMP/god6" "$URL/account/$old")
        assert_equals "301 $URL$new" "$got"
    done
    # Signed out: the sign-in, as for every page of the managers
    assert_equals "302 $URL/login" "$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' "$URL/w4os")"
    # The query of the old address kept
    assert_equals "301 $URL/w4os/regions/region?uuid=r1" \
        "$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -b "$TMP/god6" "$URL/account/regions/region?uuid=r1")"
    # No admin page linked under /account any more: /account is the visitor's own
    assert_equals 200 "$(curl -s -o "$TMP/dashboard.html" -w '%{http_code}' -b "$TMP/god6" "$URL/w4os")"
    # The admin layout escapes its links (&#x2F;)
    local links
    links=$(sed 's#&\#x2F;#/#g' "$TMP/dashboard.html" | grep -oE 'href="[^"]*"')
    assert_empty "$(echo "$links" | grep '"/account/' | grep -v '/account/logout')"
    assert_contains 'href="/w4os/settings"' "$links"
}

test_a_page_of_the_plugin_has_its_title_once_whatever_the_theme() {
    built || return 0
    # The plugin leaves it to the theme: the w4os theme shows it (Quark2 shows the content alone), Editorial and Mundana show it
    # themselves (themes of dev/themes.txt)
    local theme count themes=(w4os)
    for theme in editorial mundana; do
        [ -d "$ROOT/build/dev/user/themes/$theme" ] && cp -R "$ROOT/build/dev/user/themes/$theme" "$SITE/user/themes/" && themes+=("$theme")
    done
    for theme in "${themes[@]}"; do
        sed -i.bak -E "s/^(  theme:).*/\1 $theme/" "$SITE/user/config/system.yaml"
        sleep 3
        count=$(curl -s -L "$URL/fr/search" | tr '\n' ' ' | grep -oE '<h[1-3][^>]*>[[:space:]]*(<a[^>]*>)?[[:space:]]*Chercher[[:space:]]*(</a>)?[[:space:]]*</h[1-3]>' | wc -l | tr -d ' ')
        assert_equals "$theme 1" "$theme $count"
    done
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
    sleep 3
}

test_the_leftovers_of_the_demos_of_hadron_and_learn2_are_out_on_any_site_without_a_setting_of_its_own() {
    built || return 0
    [ -d "$ROOT/build/dev/user/themes/hadron" ] || { bashunit::skip "no hadron (dev/build.sh)"; return 0; }
    cp -R "$ROOT/build/dev/user/themes/hadron" "$ROOT/build/dev/user/themes/learn2" "$SITE/user/themes/"
    rm -f "$SITE/user/config/themes/hadron.yaml" "$SITE/user/config/themes/learn2.yaml"
    local page
    sed -i.bak -E "s/^(  theme:).*/\1 hadron/" "$SITE/user/config/system.yaml"
    sleep 3
    page=$(curl -s -L "$URL/fr/")
    assert_not_contains "getgrav.org" "$page"
    assert_not_contains "LANGUAGE.ICON" "$page"
    assert_not_contains "grav-logo.svg" "$page"
    sed -i.bak -E "s/^(  theme:).*/\1 learn2/" "$SITE/user/config/system.yaml"
    sleep 3
    assert_not_contains "grav-skeleton-rtfm-site" "$(curl -s -L "$URL/fr/")"
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
    sleep 3
}


test_the_logo_of_the_top_bar_keeps_its_ratio_and_gives_way_to_the_icon_of_the_site() {
    local css base
    css=$(cat "$ROOT/theme/w4os/css/custom.css")
    base=$(cat "$ROOT/theme/w4os/templates/partials/base.html.twig")
    # Its ratio from its file (Grav's media), the site's icon beside it
    assert_contains "media_directory('theme://images/logo')" "$base"
    assert_contains '--w4os-logo-ratio: {{ w4os_logo_ratio }}' "$base"
    assert_contains "url('theme://images/favicon/' ~ w4os_favicon_file)" "$base"
    # Never wider than its height allows, its side of the top bar the first to give room, the icon below 20 px high
    assert_contains 'width: calc(28px * var(--w4os-logo-ratio)); max-width: 100%;' "$css"
    assert_contains 'grid-template-columns: minmax(28px, 1fr) auto minmax(max-content, 1fr);' "$css"
    assert_contains 'width: clamp(0px, (100% - 20px * var(--w4os-logo-ratio)) * 999, 100%); height: auto;' "$css"
    assert_contains 'width: clamp(0px, (20px * var(--w4os-logo-ratio) - 100%) * 999, 28px)' "$css"
}

test_from_861_to_1199_px_the_menus_of_the_visitor_are_icons_and_the_day_and_night_switch_is_in_the_footer_only() {
    local css partials
    css=$(cat "$ROOT/theme/w4os/css/custom.css")
    partials="$ROOT/theme/w4os/templates/partials"
    assert_contains '@media (min-width: 861px) and (max-width: 1199.98px) {' "$css"
    assert_contains '#header .navbar-section.actions .w4os-user-current { font-size: 0; gap: 0; padding: .4rem; }' "$css"
    assert_not_contains 'data-theme-toggle' "$(cat "$partials/theme-toggle.html.twig")"
    assert_contains 'data-theme-toggle' "$(cat "$partials/theme-switch.html.twig")"
    assert_contains "{% include 'partials/theme-switch.html.twig' %}" "$(cat "$partials/footer.html.twig")"
}
