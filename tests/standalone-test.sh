#!/usr/bin/env bash
# The site on its own: its folder served by php -S on a machine with no OpenSim package, the engine and the helpers the w4os
# plugin bundles reaching a running grid over the network (friendly_fowl at dev.w4os.org): the grid's blocks, a profile with its picture,
# the guide and the search served by the site itself, under the prefix of its helpers.
#
# The site describes the grid from its login address (W4OS_STANDALONE_LOGIN, dev.w4os.org:8012 by default), as a site installed elsewhere
# does, no folder of config read. TEST SHORTCUT: the access to its database is taken from /etc/opensim, a mirror of the one of dev.w4os.org (DEVELOPERS.md, "A grid to try the
# standalone site"); a real remote install would get what lives in the ini files from the grid's engine API instead. The database
# is reached over the network at W4OS_STANDALONE_DB (host:port, dev.w4os.org:3306 by default), with the credentials of the grid's config,
# given to the site's own settings and never printed.
#
# Runs only when asked: W4OS_STANDALONE_GRID=friendly_fowl lib/bashunit/bashunit tests/standalone-test.sh

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

GRID=${W4OS_STANDALONE_GRID:-}
DB=${W4OS_STANDALONE_DB:-dev.w4os.org:3306}

standalone() {
    built || return 1
    [ -n "$GRID" ] || { bashunit::skip "W4OS_STANDALONE_GRID not set (a running grid, its config in /etc/opensim)"; return 1; }
    [ -f "/etc/opensim/grids/$GRID/Robust.HG.ini" ] || { bashunit::skip "no /etc/opensim/grids/$GRID"; return 1; }
    [ ! -e /usr/share/w4os-helpers ] && [ ! -e /usr/share/w4os-engine ] || { bashunit::skip "an OpenSim package is installed here"; return 1; }
    grep -q '^engine: bundled' "$SITE/user/config/plugins/w4os.yaml" && return 0
    # The database of the grid's accounts, from its config: the site's own settings, as a site installed elsewhere has them
    local source user password name
    source=$(grep -h -m1 -i '^\s*ConnectionString\s*=.*Database=' "/etc/opensim/grids/$GRID/Robust.HG.ini")
    name=$(echo "$source" | sed -n 's/.*Database=\([^;]*\);.*/\1/p')
    user=$(echo "$source" | sed -n 's/.*User I[dD]=\([^;]*\);.*/\1/p')
    password=$(echo "$source" | sed -n 's/.*Password=\([^;"]*\).*/\1/p')
    sed -i.bak -e "/^url:/d" -e "/^serve_helpers:/d" -e "/^engine:/d" -e "/^grid:/d" -e "/^api_url:/d" -e "/^api_key:/d" \
        "$SITE/user/config/plugins/w4os.yaml"
    rm -f "$SITE/user/config/plugins/w4os.yaml.bak"
    {
        echo "url: '$URL/helpers'"
        echo 'serve_helpers: true'
        echo 'engine: bundled'
        echo "grid: $GRID"
        echo 'bundled:'
        echo "  login: '${W4OS_STANDALONE_LOGIN:-http://dev.w4os.org:8012}'"
        echo '  database:'
        echo "    host: '$DB'"
        echo "    name: '$name'"
        echo "    user: '$user'"
        echo "    password: '$password'"
    } >>"$SITE/user/config/plugins/w4os.yaml"
    # The settings read again by Grav (it tells a change by the time of the file, to the second)
    sleep 2
}

test_the_site_serves_the_blocks_of_the_grid_itself() {
    standalone || return 0
    assert_equals 200 "$(curl -s -o "$TMP/grid-info.html" -w '%{http_code}' "$URL/helpers/blocks/grid-info")"
    assert_contains 'Friendly Fowl' "$(cat "$TMP/grid-info.html")"
}

test_a_profile_is_shown_with_its_picture() {
    standalone || return 0
    local page picture
    page=$(curl -s "$URL/profile/Bart.Simpson")
    assert_contains 'profile-banner' "$page"
    assert_contains 'Bart Simpson' "$page"
    assert_not_contains ' · helpers: ' "$page"
    picture=$(echo "$page" | grep -o '<img[^>]*src="[^"]*"' | grep -o 'src="[^"]*"' | sed 's/^src="//; s/"$//; s/&amp;/\&/g' | grep -v '^data:' | head -1)
    assert_not_empty "$picture"
    assert_equals 200 "$(curl -s -o /dev/null -w '%{http_code}' "$(case $picture in http*) echo "$picture" ;; *) echo "$URL$picture" ;; esac)")"
}

test_the_guide_and_the_search_are_shown() {
    standalone || return 0
    local guide search
    guide=$(curl -s "$URL/guide")
    assert_not_contains ' · helpers: ' "$guide"
    assert_contains 'destination' "$guide"
    search=$(curl -s "$URL/search?q=Bart")
    assert_not_contains ' · helpers: ' "$search"
    assert_contains 'Bart Simpson' "$search"
}
