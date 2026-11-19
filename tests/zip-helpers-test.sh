#!/usr/bin/env bash
# The site as a zip on a server with no OpenSim package, its grid reached through the engine API alone, set to serve the helpers
# itself under its prefix (serve_helpers, url: the site's /helpers): the pages of the helpers (profile, guide, search) and their
# pictures come from the helpers the plugin bundles; every address outside the prefix is the site's.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# sign_in_as JAR NAME: NAME signs in in the browser JAR
sign_in_as() {
    local jar=$1 nonce
    nonce=$(curl -s -c "$jar" -b "$jar" "$URL/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
    curl -s -o /dev/null -c "$jar" -b "$jar" "$URL/login" --data-urlencode "username=$2" --data-urlencode "password=secret" \
        -d "task=login.login" --data-urlencode "login-form-nonce=$nonce"
}

set_up() {
    built || return 0
    # No OpenSim package on this server: the site has nothing else to lean on
    [ ! -e /usr/share/opensim-helpers ] && [ ! -e /usr/share/opensim-engine ] || bashunit::skip "an OpenSim package is installed here"
    grep -q '^serve_helpers: true' "$SITE/user/config/plugins/w4os.yaml" && return 0
    sed -i.bak -e "/^url:/d" -e "/^serve_helpers:/d" "$SITE/user/config/plugins/w4os.yaml" && rm -f "$SITE/user/config/plugins/w4os.yaml.bak"
    printf '%s\n' "url: '$URL/helpers'" 'serve_helpers: true' >>"$SITE/user/config/plugins/w4os.yaml"
    # A page of the site whose address starts like the prefix of the helpers, without being under it
    mkdir -p "$SITE/user/pages/09.helpers-faq"
    printf '%s\n' '---' "title: 'Helpers FAQ'" '---' 'What the helpers do.' >"$SITE/user/pages/09.helpers-faq/default.md"
}

test_the_site_answers_the_blocks_of_the_helpers_under_its_prefix_itself() {
    built || return 0
    assert_equals 200 "$(curl -s -o "$TMP/grid-info.html" -w '%{http_code}' "$URL/helpers/blocks/grid-info")"
    assert_contains 'Demo Grid' "$(cat "$TMP/grid-info.html")"
}

test_an_address_outside_the_prefix_is_a_page_of_the_site() {
    built || return 0
    assert_contains '<title>Helpers FAQ' "$(curl -s "$URL/helpers-faq")"
}

test_the_profile_of_an_avatar_is_shown_with_its_picture() {
    built || return 0
    [ -s "$TMP/ada" ] || sign_in_as "$TMP/ada" "Ada Love"
    local page picture
    page=$(curl -s -b "$TMP/ada" "$URL/profile")
    assert_contains 'profile-banner' "$page"
    assert_not_contains 'The grid cannot be reached right now' "$page"
    picture=$(echo "$page" | grep -o '<img[^>]*class="[^"]*profile[^"]*"[^>]*>' | grep -o 'src="[^"]*"' | head -1 | sed 's/^src="//; s/"$//; s/&amp;/\&/g')
    assert_not_empty "$picture"
    assert_equals 200 "$(curl -s -o /dev/null -w '%{http_code}' "$(case $picture in http*) echo "$picture" ;; *) echo "$URL$picture" ;; esac)")"
}

test_the_guide_and_the_search_are_shown() {
    built || return 0
    local guide search
    guide=$(curl -s "$URL/guide")
    search=$(curl -s "$URL/search?q=ada")
    assert_not_contains 'The grid cannot be reached right now' "$guide"
    assert_contains 'destination' "$guide"
    assert_not_contains 'The grid cannot be reached right now' "$search"
    assert_contains 'Ada Love' "$search"
}
