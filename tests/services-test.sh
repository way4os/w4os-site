#!/usr/bin/env bash
# The settings of the services of the grid in the admin, end to end, as w4os-wp has them: each its page in the menu, the form of the
# engine, what the options of the grid set shown and unchangeable, a change written by the engine; for the managers only.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

test_a_god_changes_the_economy_of_the_grid_but_not_what_its_options_set() {
    built || return 0
    sign_in_as "$TMP/god" "God Test"
    local page fields name location sent
    page=$(curl -s -b "$TMP/god" -c "$TMP/god" "$URL/w4os/economy")
    assert_contains '<title>Economy Settings' "$page"
    assert_contains '/w4os/search' "$(echo "$page" | sed 's/&#x2F;/\//g')"
    assert_contains 'name="data[economyUrl]"' "$page"
    assert_matches 'name="data\[economyModule\]"[^>]*disabled' "$page"
    fields=()
    for name in __form-name__ __unique_form_id__ form-nonce; do
        fields+=(--data-urlencode "$name=$(echo "$page" | sed -n "s/.*name=\"$name\" value=\"\([^\"]*\)\".*/\1/p" | head -1)")
    done
    location=$(curl -s -o /dev/null -w '%{redirect_url}' -b "$TMP/god" -c "$TMP/god" "$URL/w4os/economy" "${fields[@]}" \
        --data-urlencode "data[economyUrl]=https://play.example.org/economy" --data-urlencode "data[economyModule]=Gloebit")
    assert_contains '/w4os/economy' "$location"
    sent=$(cat "$(php -r "echo sys_get_temp_dir();")/w4os-fake-economy-$API_PORT.json")
    assert_contains '"economyUrl":"https:\/\/play.example.org\/economy"' "$sent"
    assert_contains '"economyModule":"BetaGridLikeMoneyModule"' "$sent"
}

test_a_resident_never_gets_them() {
    built || return 0
    sign_in_as "$TMP/ada" "Ada Love"
    assert_not_contains 'name="data[economyUrl]"' "$(curl -s -L -b "$TMP/ada" "$URL/w4os/economy")"
}
