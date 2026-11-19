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
    page=$(curl -s -b "$TMP/god" "$URL/w4os/settings")
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
    assert_equals 302 "$(curl -s -o /dev/null -w '%{http_code}' -b "$TMP/ada" "$URL/w4os/settings")"
}

test_the_logo_and_the_favicon_of_the_site_are_asked_whatever_the_theme() {
    built || return 0
    cp -R "$ROOT/build/dev/user/themes/." "$SITE/user/themes/" 2>/dev/null || true
    [ -d "$SITE/user/themes/woo" ] || { bashunit::skip "no theme of development (dev/themes.sh)"; return 0; }
    sign_in_as "$TMP/god2" "God Test"
    local page theme
    for theme in quark2 woo; do
        # Grav sees a changed configuration once PHP takes its compiled file again (OPcache, every 2 seconds by default)
        sleep 3
        sed -i.bak -E "s/^(  theme:).*/\1 $theme/" "$SITE/user/config/system.yaml"
        page=$(curl -s -b "$TMP/god2" "$URL/w4os/settings")
        assert_matches "value=\"$theme\"[^>]*checked" "$page"
        # The file fields of the Form plugin (Dropzone), their settings in an attribute
        assert_contains '&quot;name&quot;&#x3A;&quot;logo&quot;' "$page"
        assert_contains '&quot;name&quot;&#x3A;&quot;favicon&quot;' "$page"
    done
    sleep 3
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
}

test_a_theme_saved_shows_at_once_on_the_settings_page_and_on_the_site() {
    built || return 0
    sign_in_as "$TMP/god3" "God Test"
    local form fields page
    form=$(curl -s -b "$TMP/god3" -c "$TMP/god3" "$URL/w4os/settings")
    fields=()
    for name in __form-name__ __unique_form_id__ form-nonce; do
        fields+=(--data-urlencode "$name=$(echo "$form" | sed -n "s/.*name=\"$name\" value=\"\([^\"]*\)\".*/\1/p" | head -1)")
    done
    # Saved, then the page the save leads to and the home page, at once
    page=$(curl -s -L -b "$TMP/god3" -c "$TMP/god3" "$URL/w4os/settings" "${fields[@]}" --data-urlencode "data[theme]=quark2")
    assert_matches 'value="quark2"[^>]*checked' "$page"
    assert_contains '/user/themes/quark2/' "$(curl -s -L -b "$TMP/god3" "$URL/")"
    assert_not_contains '/user/themes/w4os/' "$(curl -s -L -b "$TMP/god3" "$URL/")"
    sleep 3
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
}

# save_settings JAR FIELD=VALUE...: the settings saved by the god of JAR, with the fields of its form and these
save_settings() {
    local jar=$1 form name fields=()
    shift
    form=$(curl -s -b "$jar" -c "$jar" "$URL/w4os/settings")
    for name in __form-name__ __unique_form_id__ form-nonce; do
        fields+=(--data-urlencode "$name=$(echo "$form" | sed -n "s/.*name=\"$name\" value=\"\([^\"]*\)\".*/\1/p" | head -1)")
    done
    for name in "$@"; do fields+=(--data-urlencode "$name"); done
    curl -s -o /dev/null -b "$jar" -c "$jar" "$URL/w4os/settings" "${fields[@]}"
}

test_the_brand_is_the_site_s_shown_by_every_theme_what_a_theme_kept_before_becomes_it() {
    built || return 0
    local config mine icon theme json
    sleep 3
    mine=user/data/theme/images/logo/friendly-fowl-brand.png
    icon=user/themes/w4os/images/favicon/opensimulator-logo-square.png
    mkdir -p "$SITE/user/data/theme/images/logo" "$SITE/user/config/themes"
    cp "$SITE/user/themes/w4os/images/logo/opensimulator-logo.png" "$SITE/$mine"
    # A site that saved its brand in the theme before: its own logo, the theme's favicon, a setting of its own
    printf '%s\n' 'accent-color: '"'"'#8428df'"'" 'custom_logo:' "  $mine:" '    name: friendly-fowl-brand.png' '    type: image/png' \
        "    path: $mine" 'custom_favicon:' "  $icon:" '    name: opensimulator-logo-square.png' '    type: image/png' "    path: $icon" \
        >"$SITE/user/config/themes/w4os.yaml"
    # Grav lists its configuration files again once its check interval is over (2 seconds), PHP its compiled files (OPcache)
    sleep 3
    sign_in_as "$TMP/god4" "God Test"
    # Shown as the site's, saved as the site's: out of the theme, the theme's own favicon no brand of the site
    assert_contains 'friendly-fowl-brand.png' "$(curl -s -b "$TMP/god4" "$URL/w4os/settings")"
    json="{\"$mine\":{\"name\":\"friendly-fowl-brand.png\",\"type\":\"image/png\",\"path\":\"$mine\"}}"
    save_settings "$TMP/god4" "data[theme]=w4os" "data[_json][logo]=$json" \
        "data[_json][favicon]={\"$icon\":{\"name\":\"opensimulator-logo-square.png\",\"type\":\"image/png\",\"path\":\"$icon\"}}"
    config=$(cat "$SITE/user/config/themes/w4os.yaml")
    assert_not_contains "custom_logo" "$config"
    assert_not_contains "custom_favicon" "$config"
    assert_contains "accent-color" "$config"
    config=$(sed -n '/^brand:/,/^[a-z]/p' "$SITE/user/config/plugins/w4os.yaml")
    assert_contains "$mine" "$config"
    assert_not_contains "favicon" "$config"
    # The same logo whatever the theme the site switches to, Editorial's switch on with it (a theme of dev/themes.txt)
    local themes=(quark2 w4os)
    [ -d "$ROOT/build/dev/user/themes/editorial" ] && cp -R "$ROOT/build/dev/user/themes/editorial" "$SITE/user/themes/" && themes+=(editorial)
    for theme in "${themes[@]}"; do
        sleep 3
        sed -i.bak -E "s/^(  theme:).*/\1 $theme/" "$SITE/user/config/system.yaml"
        # The copy the theme's own field would have made, the file in the site's data as it is
        assert_contains "/user/themes/$theme/images/logo/friendly-fowl-brand.png\"" "$(curl -s -L "$URL/")"
        assert_file_exists "$SITE/$mine"
    done
    sleep 3
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
    # No brand of the site (its files removed from the form, as Dropzone posts it): each theme its own
    save_settings "$TMP/god4" "data[theme]=w4os" "data[_json][logo]=[]" "data[_json][favicon]=[]"
    assert_not_contains "brand:" "$(cat "$SITE/user/config/plugins/w4os.yaml")"
    sleep 3
    assert_contains "opensimulator-logo.png" "$(curl -s -L "$URL/")"
    rm -f "$SITE/user/config/themes/w4os.yaml"
    sleep 3
}

test_the_settings_open_under_a_theme_that_names_its_folders_its_own_way() {
    built || return 0
    # Future2021 asks its favicon in theme@:/images, the older way of Grav's admin (a theme of dev/themes.txt)
    [ -d "$ROOT/build/dev/user/themes/future2021" ] || { bashunit::skip "no future2021 (dev/build.sh)"; return 0; }
    cp -R "$ROOT/build/dev/user/themes/future2021" "$SITE/user/themes/"
    sed -i.bak -E "s/^(  theme:).*/\1 future2021/" "$SITE/user/config/system.yaml"
    sleep 3
    sign_in_as "$TMP/god5" "God Test"
    local page
    assert_equals 200 "$(curl -s -o "$TMP/future2021.html" -w '%{http_code}' -b "$TMP/god5" "$URL/w4os/settings")"
    page=$(cat "$TMP/future2021.html")
    # Its favicon asked like the others
    assert_contains '&quot;name&quot;&#x3A;&quot;favicon&quot;' "$page"
    assert_equals 200 "$(curl -s -o /dev/null -w '%{http_code}' "$URL/")"
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
    sleep 3
}

test_a_theme_without_a_logo_field_gets_the_site_s_logo_in_its_own_file_and_its_own_back_without_it() {
    built || return 0
    # Woo takes its logo from images/logo.png, no field for it (a theme of dev/themes.txt)
    [ -d "$ROOT/build/dev/user/themes/woo" ] || { bashunit::skip "no woo (dev/build.sh)"; return 0; }
    cp -R "$ROOT/build/dev/user/themes/woo" "$SITE/user/themes/"
    local mine=user/data/theme/images/logo/friendly-fowl-brand.png own
    own=$(md5 -q "$SITE/user/themes/woo/images/logo.png" 2>/dev/null || md5sum "$SITE/user/themes/woo/images/logo.png" | cut -d' ' -f1)
    mkdir -p "$SITE/user/data/theme/images/logo"
    cp "$SITE/user/themes/w4os/images/logo/opensimulator-logo.png" "$SITE/$mine"
    cp "$SITE/user/config/plugins/w4os.yaml" "$TMP/w4os-woo.yaml"
    printf '%s\n' 'brand:' '  logo:' "    $mine:" '      name: friendly-fowl-brand.png' '      type: image/png' "      path: $mine" \
        >>"$SITE/user/config/plugins/w4os.yaml"
    sed -i.bak -E "s/^(  theme:).*/\1 woo/" "$SITE/user/config/system.yaml"
    sleep 3
    sign_in_as "$TMP/god7" "God Test"
    curl -s -o /dev/null "$URL/"
    assert_files_equals "$SITE/$mine" "$SITE/user/themes/woo/images/logo.png"
    assert_file_exists "$SITE/user/data/w4os/theme-files/woo/images/logo.png"
    # The settings page: no notice for the logo under Woo
    assert_not_contains "affiche pas de logo" "$(curl -s -b "$TMP/god7" "$URL/fr/w4os/settings")"
    # No brand for the site: Woo's own logo back
    cp "$TMP/w4os-woo.yaml" "$SITE/user/config/plugins/w4os.yaml"
    sleep 3
    curl -s -o /dev/null "$URL/"
    assert_equals "$own" "$(md5 -q "$SITE/user/themes/woo/images/logo.png" 2>/dev/null || md5sum "$SITE/user/themes/woo/images/logo.png" | cut -d' ' -f1)"
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
    sleep 3
}

test_hypertext_shows_the_favicon_of_the_site_from_the_file_it_takes_it_from() {
    built || return 0
    [ -d "$ROOT/build/dev/user/themes/hypertext" ] || { bashunit::skip "no hypertext (dev/build.sh)"; return 0; }
    cp -R "$ROOT/build/dev/user/themes/hypertext" "$SITE/user/themes/"
    local icon=user/data/theme/images/favicon/friendly-fowl-icon.png
    mkdir -p "$SITE/user/data/theme/images/favicon"
    cp "$SITE/user/themes/w4os/images/favicon/opensimulator-logo-square.png" "$SITE/$icon"
    cp "$SITE/user/config/plugins/w4os.yaml" "$TMP/w4os-hypertext.yaml"
    printf '%s\n' 'brand:' '  favicon:' "    $icon:" '      name: friendly-fowl-icon.png' '      type: image/png' "      path: $icon" \
        >>"$SITE/user/config/plugins/w4os.yaml"
    sed -i.bak -E "s/^(  theme:).*/\1 hypertext/" "$SITE/user/config/system.yaml"
    sleep 3
    assert_contains 'favicon/favicon.png' "$(curl -s -L "$URL/fr/")"
    assert_files_equals "$SITE/$icon" "$SITE/user/images/favicon/favicon.png"
    cp "$TMP/w4os-hypertext.yaml" "$SITE/user/config/plugins/w4os.yaml"
    sed -i.bak -E "s/^(  theme:).*/\1 w4os/" "$SITE/user/config/system.yaml"
    sleep 3
}

test_a_god_chooses_a_custom_list_of_avatar_models_and_its_avatars_in_one_save_seeing_the_models_they_pick() {
    built || return 0
    # The god's session of before: Grav limits the sign-ins of an account
    [ -s "$TMP/god" ] || sign_in_as "$TMP/god" "God Test"
    local form fields name rule
    rule="$(php -r "echo sys_get_temp_dir();")/w4os-fake-models-$API_PORT.json"
    echo '{"match":"any","pattern":"Default","list":[]}' >"$rule"
    form=$(curl -s -b "$TMP/god" -c "$TMP/god" "$URL/w4os/models")
    # Match as radios, the list in the form though the rule takes names (hidden by the script until the custom list is chosen),
    # the models the rule picks under it, the page under Avatars in the menu
    assert_contains 'type="radio"' "$form"
    assert_contains 'value="uuid"' "$form"
    assert_contains 'name="data[list][]"' "$form"
    assert_contains 'w4os-unmet' "$form"
    assert_contains 'data-w4os-conditions=' "$form"
    assert_contains 'Default Ruth' "$form"
    assert_contains 'dropdown-item active' "$form"
    # The models of a rule before it is saved
    assert_contains 'God Test' "$(curl -s -b "$TMP/god" "$URL/w4os/models?format=preview&filter%5Bmatch%5D=uuid&filter%5Blist%5D=g1")"
    assert_not_contains 'Default Ruth' "$(curl -s -b "$TMP/god" "$URL/w4os/models?format=preview&filter%5Bmatch%5D=uuid&filter%5Blist%5D=g1")"
    fields=()
    for name in __form-name__ __unique_form_id__ form-nonce; do
        fields+=(--data-urlencode "$name=$(echo "$form" | sed -n "s/.*name=\"$name\" value=\"\([^\"]*\)\".*/\1/p" | head -1)")
    done
    curl -s -o "$TMP/models-saved.html" -L -b "$TMP/god" -c "$TMP/god" "$URL/w4os/models" "${fields[@]}" \
        --data-urlencode "data[match]=uuid" --data-urlencode "data[pattern]=Default" --data-urlencode "data[list][]=g1" \
        --data-urlencode "data[list][]=a1"
    assert_not_contains "Array to string" "$(cat "$TMP/models-saved.html")"
    assert_contains '"match":"uuid"' "$(cat "$rule")"
    assert_contains '"list":["g1","a1"]' "$(cat "$rule")"
    rm -f "$rule"
}
