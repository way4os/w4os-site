#!/usr/bin/env bash
# The settings of the site, end to end: a god opens them in the admin of the site (the w4os plugin) and finds the theme among the
# ones installed, the site's chosen; a resident never gets them.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

test_a_god_finds_the_theme_among_the_ones_installed_the_site_s_chosen_under_the_title_of_the_page() {
    built || return 0
    local page
    sign_in_as "$TMP/god" "God Test"
    page=$(curl -s -b "$TMP/god" "$URL/account/settings")
    assert_contains "<title>Site settings" "$page"
    assert_not_contains "w4os.settings_title" "$page"
    assert_contains "Theme" "$page"
    # A gallery of the themes, a radio each, the site's checked, each by its name
    assert_matches 'value="w4os"[^>]*checked' "$page"
    assert_contains 'w4os site' "$page"
    assert_contains 'value="quark2"' "$page"
    assert_contains 'Quark 2' "$page"
}

test_a_resident_never_gets_them() {
    built || return 0
    sign_in_as "$TMP/ada" "Ada Love"
    assert_equals 302 "$(curl -s -o /dev/null -w '%{http_code}' -b "$TMP/ada" "$URL/account/settings")"
}

test_the_logo_and_the_favicon_are_asked_only_of_a_theme_that_has_its_own_fields_for_them() {
    built || return 0
    cp -R "$ROOT/build/dev/user/themes/." "$SITE/user/themes/" 2>/dev/null || true
    [ -d "$SITE/user/themes/woo" ] || { bashunit::skip "no theme of development (dev/themes.sh)"; return 0; }
    sign_in_as "$TMP/god2" "God Test"
    local page
    # Grav sees a changed configuration once PHP takes its compiled file again (OPcache, every 2 seconds by default)
    sleep 3
    sed -i.bak -E "s/^(  theme:).*/\1 quark2/" "$SITE/user/config/system.yaml"
    page=$(curl -s -b "$TMP/god2" "$URL/account/settings")
    assert_matches 'value="quark2"[^>]*checked' "$page"
    # The file fields of the Form plugin (Dropzone), their settings in an attribute
    assert_contains '&quot;name&quot;&#x3A;&quot;logo&quot;' "$page"
    assert_contains '&quot;name&quot;&#x3A;&quot;favicon&quot;' "$page"
    sleep 3
    sed -i.bak -E "s/^(  theme:).*/\1 woo/" "$SITE/user/config/system.yaml"
    page=$(curl -s -b "$TMP/god2" "$URL/account/settings")
    assert_matches 'value="woo"[^>]*checked' "$page"
    assert_not_contains '&quot;name&quot;&#x3A;&quot;logo&quot;' "$page"
    sleep 3
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
}

test_a_theme_saved_shows_at_once_on_the_settings_page_and_on_the_site() {
    built || return 0
    sign_in_as "$TMP/god3" "God Test"
    local form fields page
    form=$(curl -s -b "$TMP/god3" -c "$TMP/god3" "$URL/account/settings")
    fields=()
    for name in __form-name__ __unique_form_id__ form-nonce; do
        fields+=(--data-urlencode "$name=$(echo "$form" | sed -n "s/.*name=\"$name\" value=\"\([^\"]*\)\".*/\1/p" | head -1)")
    done
    # Saved, then the page the save leads to and the home page, at once
    page=$(curl -s -L -b "$TMP/god3" -c "$TMP/god3" "$URL/account/settings" "${fields[@]}" --data-urlencode "data[theme]=quark2")
    assert_matches 'value="quark2"[^>]*checked' "$page"
    assert_contains '/user/themes/quark2/' "$(curl -s -L -b "$TMP/god3" "$URL/")"
    assert_not_contains '/user/themes/w4os/' "$(curl -s -L -b "$TMP/god3" "$URL/")"
    sleep 3
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
}

test_the_settings_saved_keep_in_the_site_only_what_is_not_the_theme_s_own_default() {
    built || return 0
    sign_in_as "$TMP/god4" "God Test"
    local form fields config logo mine
    logo=user/themes/w4os/images/logo/opensimulator-logo.png
    mine=user/data/theme/images/logo/friendly-fowl-brand.png
    # A site that saved its brand before: its own logo, the theme's favicon written in its configuration, a setting of its own
    mkdir -p "$SITE/user/config/themes"
    printf '%s\n' 'accent-color: '"'"'#8428df'"'" 'custom_logo:' "  $mine:" '    name: friendly-fowl-brand.png' '    type: image/png' \
        "    path: $mine" 'custom_favicon:' '  user/themes/w4os/images/favicon/opensimulator-logo-square.png:' \
        '    name: opensimulator-logo-square.png' '    type: image/png' '    path: user/themes/w4os/images/favicon/opensimulator-logo-square.png' \
        >"$SITE/user/config/themes/w4os.yaml"
    sleep 3
    form=$(curl -s -b "$TMP/god4" -c "$TMP/god4" "$URL/account/settings")
    fields=()
    for name in __form-name__ __unique_form_id__ form-nonce; do
        fields+=(--data-urlencode "$name=$(echo "$form" | sed -n "s/.*name=\"$name\" value=\"\([^\"]*\)\".*/\1/p" | head -1)")
    done
    # Saved with its own logo and the favicon of the theme, then with the logo of the theme
    curl -s -o /dev/null -b "$TMP/god4" -c "$TMP/god4" "$URL/account/settings" "${fields[@]}" --data-urlencode "data[theme]=w4os" \
        --data-urlencode "data[_json][logo]={\"$mine\":{\"name\":\"friendly-fowl-brand.png\",\"type\":\"image/png\",\"path\":\"$mine\"}}" \
        --data-urlencode "data[_json][favicon]={\"user/themes/w4os/images/favicon/opensimulator-logo-square.png\":{\"name\":\"opensimulator-logo-square.png\",\"type\":\"image/png\",\"path\":\"user/themes/w4os/images/favicon/opensimulator-logo-square.png\"}}"
    config=$(cat "$SITE/user/config/themes/w4os.yaml")
    assert_contains "$mine" "$config"
    assert_not_contains "custom_favicon" "$config"
    assert_contains "accent-color" "$config"
    form=$(curl -s -b "$TMP/god4" -c "$TMP/god4" "$URL/account/settings")
    fields=()
    for name in __form-name__ __unique_form_id__ form-nonce; do
        fields+=(--data-urlencode "$name=$(echo "$form" | sed -n "s/.*name=\"$name\" value=\"\([^\"]*\)\".*/\1/p" | head -1)")
    done
    curl -s -o /dev/null -b "$TMP/god4" -c "$TMP/god4" "$URL/account/settings" "${fields[@]}" --data-urlencode "data[theme]=w4os" \
        --data-urlencode "data[_json][logo]={\"$logo\":{\"name\":\"opensimulator-logo.png\",\"type\":\"image/png\",\"path\":\"$logo\"}}"
    config=$(cat "$SITE/user/config/themes/w4os.yaml")
    assert_not_contains "custom_logo" "$config"
    assert_contains "accent-color" "$config"
    rm -f "$SITE/user/config/themes/w4os.yaml"
    sleep 3
}
