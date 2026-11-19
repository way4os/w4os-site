#!/usr/bin/env bash
# A new avatar from the admin, end to end, as w4os-wp makes one: the button above the list, the form of the engine (the names, the
# email, the password, the models), the avatar made active at once, then its page.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

test_a_god_makes_a_new_avatar_from_the_list_of_the_avatars() {
    built || return 0
    sign_in_as "$TMP/god" "God Test"
    local list form fields name sent location
    list=$(curl -s -b "$TMP/god" "$URL/w4os/avatars")
    assert_contains '/w4os/avatars/new' "$(echo "$list" | sed 's/&#x2F;/\//g')"
    assert_contains 'New Avatar' "$list"
    form=$(curl -s -b "$TMP/god" -c "$TMP/god" "$URL/w4os/avatars/new")
    assert_contains '<title>New Avatar' "$form"
    assert_contains 'Choose a name below.' "$form"
    assert_contains 'name="data[firstName]"' "$form"
    assert_contains 'pattern="[A-Za-z][A-Za-z0-9]*"' "$form"
    assert_contains 'name="data[password]"' "$form"
    assert_contains 'Create Avatar' "$form"
    fields=()
    for name in __form-name__ __unique_form_id__ form-nonce; do
        fields+=(--data-urlencode "$name=$(echo "$form" | sed -n "s/.*name=\"$name\" value=\"\([^\"]*\)\".*/\1/p" | head -1)")
    done
    location=$(curl -s -o /dev/null -w '%{redirect_url}' -b "$TMP/god" -c "$TMP/god" "$URL/w4os/avatars/new" "${fields[@]}" \
        --data-urlencode "data[firstName]=Nova" --data-urlencode "data[lastName]=Star" --data-urlencode "data[email]=" \
        --data-urlencode "data[password]=secret1")
    assert_contains '/w4os/avatars/edit?avatar=n1' "$location"
    sent=$(cat "$(php -r "echo sys_get_temp_dir();")/w4os-fake-new-avatar-$API_PORT.json")
    assert_contains '"firstName":"Nova"' "$sent"
    assert_contains '"active":true' "$sent"
    assert_not_contains '"email"' "$sent"
}

test_a_resident_never_gets_the_page() {
    built || return 0
    sign_in_as "$TMP/ada" "Ada Love"
    assert_not_contains 'name="data[firstName]"' "$(curl -s -L -b "$TMP/ada" "$URL/w4os/avatars/new")"
}
