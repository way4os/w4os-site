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

test_a_god_gives_the_address_of_the_economy_elsewhere_and_what_provide_hides_is_not_sent() {
    built || return 0
    sign_in_as "$TMP/god" "God Test"
    local page fields name location sent
    page=$(curl -s -b "$TMP/god" -c "$TMP/god" "$URL/w4os/economy")
    assert_contains '<title>Economy Settings' "$page"
    assert_contains '/w4os/search' "$(echo "$page" | sed 's/&#x2F;/\//g')"
    assert_contains 'name="data[economyUrl]"' "$page"
    assert_contains 'name="data[economyModule]"' "$page"
    assert_not_matches 'name="data\[economyModule\]"[^>]*disabled' "$page"
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

test_a_god_sees_the_lines_of_the_grid_and_is_told_the_page_of_the_service_is_missing() {
    built || return 0
    sign_in_as "$TMP/god" "God Test"
    local page fields name after
    page=$(curl -s -b "$TMP/god" -c "$TMP/god" "$URL/w4os/guide")
    assert_contains 'Robust.HG.ini' "$page"
    assert_contains 'DestinationGuide = http://127.0.0.1/nowhere' "$page"
    assert_contains 'form-switch' "$page"
    assert_matches 'input-group-text">http://127.0.0.1' "$page"
    fields=()
    for name in __form-name__ __unique_form_id__ form-nonce; do
        fields+=(--data-urlencode "$name=$(echo "$page" | sed -n "s/.*name=\"$name\" value=\"\([^\"]*\)\".*/\1/p" | head -1)")
    done
    after=$(curl -s -L -b "$TMP/god" -c "$TMP/god" "$URL/w4os/guide" "${fields[@]}" --data-urlencode "data[provide]=1" --data-urlencode "data[path]=/nowhere" --data-urlencode "data[guideSource]=destinations.txt")
    assert_contains 'Settings saved.' "$after"
    assert_contains 'The site has no page at /nowhere' "$after"
}

test_a_god_runs_the_indexing_of_the_search_now() {
    built || return 0
    sign_in_as "$TMP/god" "God Test"
    local page nonce after
    page=$(curl -s -b "$TMP/god" -c "$TMP/god" "$URL/w4os/search")
    assert_contains 'Index the regions' "$page"
    assert_contains 'no simulator due' "$page"
    assert_not_contains 'another grid' "$page"
    nonce=$(echo "$page" | sed -n 's/.*name="nonce" value="\([^"]*\)".*/\1/p' | head -1)
    after=$(curl -s -L -b "$TMP/god" -c "$TMP/god" "$URL/w4os/search" --data-urlencode "action=run_task" --data-urlencode "task=demo:search-parse" --data-urlencode "nonce=$nonce")
    assert_contains '2 regions indexed' "$after"
}

test_a_resident_never_gets_them() {
    built || return 0
    sign_in_as "$TMP/ada" "Ada Love"
    assert_not_contains 'name="data[economyUrl]"' "$(curl -s -L -b "$TMP/ada" "$URL/w4os/economy")"
}
