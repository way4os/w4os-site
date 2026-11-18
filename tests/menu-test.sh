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

# home THEME JAR: the home page under a theme, as the browser JAR sees it
home() {
    sed -i.bak -E "s/^(  theme:).*/\1 $1/" "$SITE/user/config/system.yaml"
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
        page=$(home "$theme" "$TMP/ada")
        assert_contains 'href="/profile"' "$page"
        assert_contains 'href="/account"' "$page"
        assert_contains 'href="/account/logout"' "$page"
        assert_not_contains 'href="/account/dashboard"' "$page"
        page=$(home "$theme" "$TMP/god")
        assert_contains 'href="/account/dashboard"' "$page"
        assert_contains 'href="/account/settings"' "$page"
    done
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
}

test_my_avatar_is_the_profile_of_the_avatar_signed_in_and_the_registration_for_a_visitor() {
    built || return 0
    sign_in_as "$TMP/ada2" "Ada Love"
    assert_equals 302 "$(curl -s -o /dev/null -w '%{http_code}' "$URL/profile")"
    assert_contains "/register" "$(curl -s -o /dev/null -w '%{redirect_url}' "$URL/profile")"
    assert_contains "Ada Love" "$(curl -s -b "$TMP/ada2" "$URL/profile")"
}

test_logout_signs_out_as_the_login_plugin_does() {
    built || return 0
    sign_in_as "$TMP/ada3" "Ada Love"
    assert_contains "login.logout" "$(curl -s -o /dev/null -w '%{redirect_url}' -b "$TMP/ada3" "$URL/account/logout")"
}
