#!/usr/bin/env bash
# Any password OpenSim takes, end to end through the forms of the site: a registration, a change and a reset with a long password
# and a short one, of quotes and spaces, then a sign-in with all of it (a field that cuts or refuses it would leave the avatar a
# password it does not know).

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# Twenty characters, a quote, a double quote, spaces; four, a double quote and a space
LONG='don'"'"'t say "hi" 2026!'
SHORT='a "b'

set_up_before_script() {
    site_set_up
    [ -z "${API_PORT:-}" ] || rm -f "$(php -r 'echo sys_get_temp_dir();')/w4os-fake-passwords-$API_PORT.json"
}

# sign_in_with JAR NAME PASSWORD: NAME signs in with PASSWORD in the browser JAR
sign_in_with() {
    local nonce
    nonce=$(curl -s -c "$1" -b "$1" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$1" -b "$1" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=$3" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

signed_in() {
    assert_contains "task:login.logout" "$(curl -s -b "$1" "$URL/login")"
}

# submit JAR PAGE FORM [field=value...]: the form of PAGE as it is drawn (its name, its id, its token), sent with the fields
submit() {
    local jar=$1 page=$2 form name fields=()
    shift 2
    form=$(curl -s -c "$jar" -b "$jar" "$URL$page")
    for name in __form-name__ __unique_form_id__ form-nonce; do
        fields+=(--data-urlencode "$name=$(sed -n "s/.*name=\"$name\" value=\"\([^\"]*\)\".*/\1/p" <<<"$form" | head -1)")
    done
    for name in "$@"; do
        fields+=(--data-urlencode "$name")
    done
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL${page%%\?*}" "${fields[@]}"
}

# password_fields PAGE JAR: the password inputs of PAGE as drawn
password_fields() {
    curl -s -b "${2:-/dev/null}" "$URL$1" | tr '\n' ' ' | grep -oE '<input[^>]*type="password"[^>]*>'
}

test_a_registration_takes_a_long_or_a_short_password_of_quotes_and_spaces_whole() {
    built || return 0
    local fields page
    fields=$(password_fields /register)
    assert_not_empty "$fields"
    assert_not_contains 'maxlength' "$fields"
    assert_not_contains 'minlength' "$fields"
    assert_not_contains 'pattern' "$fields"
    # The help under the field says nothing of a length
    page=$(curl -s "$URL/register")
    assert_contains 'The same password logs you in here and in-world.' "$page"
    assert_not_contains '16 characters' "$page"
    submit "$TMP/r" /register "data[first_name]=Long" "data[last_name]=Word" "data[email]=long@example.org" \
        "data[password]=$LONG" "data[password_confirm]=$LONG"
    sign_in_with "$TMP/r2" "Long Word" "$LONG"
    signed_in "$TMP/r2"
    submit "$TMP/r" /register "data[first_name]=Short" "data[last_name]=Word" "data[email]=short@example.org" \
        "data[password]=$SHORT" "data[password_confirm]=$SHORT"
    sign_in_with "$TMP/r3" "Short Word" "$SHORT"
    signed_in "$TMP/r3"
}

test_a_change_of_password_takes_a_long_or_a_short_password_of_quotes_and_spaces_whole() {
    built || return 0
    sign_in_with "$TMP/c" "Ada Love" secret
    assert_not_contains 'maxlength' "$(password_fields /account "$TMP/c")"
    submit "$TMP/c" /account "data[email]=ada@example.org" "data[current]=secret" "data[password]=$LONG" "data[password_confirm]=$LONG"
    sign_in_with "$TMP/c2" "Ada Love" "$LONG"
    signed_in "$TMP/c2"
    submit "$TMP/c2" /account "data[email]=ada@example.org" "data[current]=$LONG" "data[password]=$SHORT" "data[password_confirm]=$SHORT"
    sign_in_with "$TMP/c3" "Ada Love" "$SHORT"
    signed_in "$TMP/c3"
}

test_a_reset_takes_a_long_or_a_short_password_of_quotes_and_spaces_whole() {
    built || return 0
    local password i=0
    assert_not_contains 'maxlength' "$(password_fields '/reset-password?token=reset-ada')"
    for password in "$LONG, reset" "$SHORT"; do
        submit "$TMP/s" '/reset-password?token=reset-ada' "data[token]=reset-ada" "data[password]=$password" "data[password_confirm]=$password"
        sign_in_with "$TMP/s$((i += 1))" "Ada Love" "$password"
        signed_in "$TMP/s$i"
    done
}
