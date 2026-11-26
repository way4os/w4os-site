#!/usr/bin/env bash
# The page where an avatar edits its profile: its picture, as the In-world tab of the viewer shows it, a silhouette the site serves
# itself when the picture cannot be loaded; nothing there of adding the grid to a viewer, which belongs to the pages for it.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

sign_in_as() {
    local nonce
    nonce=$(curl -s -c "$1" -b "$1" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$1" -b "$1" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

test_the_profile_edit_page_shows_the_picture_of_the_avatar_and_a_silhouette_the_site_serves_when_it_fails() {
    built || return 0
    local page silhouette
    sign_in_as "$TMP/ada" "Ada Love"
    page=$(curl -s -b "$TMP/ada" "$URL/account" | tr '\n' ' ')
    assert_contains 'class="w4os-picture w4os-pic w4os-identity-picture"><img src="' "$page"
    assert_contains '/11111111-2222-3333-4444-555555555555.jpg' "$page"
    # The silhouette from the site itself, never from the server whose picture failed
    silhouette=$(grep -oE "this\.src='[^']*'" <<<"$page" | head -1 | sed "s/this.src='//; s/'$//")
    assert_contains '/user/plugins/w4os/vendor/w4os/w4os-engine/share/images/assets-no-person.png' "$silhouette"
    assert_equals 200 "$(curl -s -o /dev/null -w '%{http_code}' "$URL${silhouette#"$URL"}")"
}

test_the_profile_edit_page_never_offers_to_add_the_grid_to_a_viewer() {
    built || return 0
    local page
    # An avatar that logged in-world: its steps of a newcomer done
    sign_in_as "$TMP/god" "God Test"
    page=$(curl -s -b "$TMP/god" "$URL/account")
    # The block that adds the grid (its button, the other scheme, the login URI); a newcomer's steps may still say to add it
    assert_not_contains 'class="w4os-add-grid"' "$page"
    assert_not_contains 'w4os-add-grid-other' "$page"
    assert_not_contains 'Other link' "$page"
}

test_the_link_of_the_other_scheme_says_which_where_the_grid_is_added() {
    built || return 0
    local page
    page=$(curl -s "$URL/register/confirm")
    assert_contains 'class="w4os-add-grid-other" href="secondlife' "$page"
    assert_contains '>secondlife:// link</a>' "$page"
    assert_not_contains 'Other link' "$page"
}
