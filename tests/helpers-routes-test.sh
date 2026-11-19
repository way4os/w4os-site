#!/usr/bin/env bash
# The helpers the w4os plugin bundles, served by the site (the bundled engine, serve_helpers): they answer under the prefix of the
# helpers the site is set with when the grid sets one of its helpers there (its economy, here), never another route: outside it,
# or with another prefix, the address is the site's (its page, or its 404).

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# serving PREFIX: the site set to serve the helpers itself under PREFIX, with the bundled engine and the grid of an OpenSim install
# of the server (a small one in the temporary folder: the grid demo, its web site the site, its helpers set there under /helpers by
# its economy)
serving() {
    local install="$TMP/opensim"
    if [ ! -f "$install/opensim.conf" ]; then
        mkdir -p "$install/etc/grids/demo" "$install/etc/robust.d" "$install/cache" "$install/var" "$install/logs" "$install/data"
        printf '%s\n' '[Grid]' 'GridName = Demo Grid' >"$install/etc/grids/demo/demo.conf"
        printf '%s\n' '[Const]' '    BaseURL = "http://127.0.0.1"' "    WebURL = \"$URL\"" '    PublicPort = 8002' '    PrivatePort = 8003' \
            '[GridInfoService]' '    gridname = "Demo Grid"' '    gridnick = "demo"' "    economy = \"$URL/helpers/\"" \
            >"$install/etc/grids/demo/Robust.HG.ini"
        ln -s "$install/etc/grids/demo/Robust.HG.ini" "$install/etc/robust.d/demo.ini"
        printf '%s\n' '[Defaults]' "EtcRoot = $install/etc" "CacheRoot = $install/cache" "VarRoot = $install/var" \
            "LogsRoot = $install/logs" "DataRoot = $install/data" >"$install/opensim.conf"
    fi
    # Already so: nothing to change
    grep -qx "url: '$URL$1'" "$SITE/user/config/plugins/w4os.yaml" && return 0
    sed -i.bak -e "/^url:/d" -e "/^serve_helpers:/d" -e "/^engine:/d" -e "/^grid:/d" -e "/^bundled:/,/^[^ ]/{/^bundled:/d;/^  /d;}" \
        "$SITE/user/config/plugins/w4os.yaml"
    rm -f "$SITE/user/config/plugins/w4os.yaml.bak"
    printf '%s\n' "url: '$URL$1'" 'serve_helpers: true' 'engine: bundled' 'grid: demo' 'bundled:' "  opensim_conf: '$install/opensim.conf'" \
        >>"$SITE/user/config/plugins/w4os.yaml"
    # The settings read again by Grav (it tells a change by the time of the file, to the second)
    sleep 2
    if [ ! -d "$SITE/user/pages/09.helpers-faq" ]; then
        mkdir -p "$SITE/user/pages/09.helpers-faq"
        printf '%s\n' '---' "title: 'Helpers FAQ'" '---' 'What the helpers do.' >"$SITE/user/pages/09.helpers-faq/default.md"
        # The new page found by Grav
        sleep 2
    fi
}

test_the_helpers_set_by_the_grid_under_the_prefix_answer_there() {
    built || return 0
    serving /helpers
    assert_equals 200 "$(curl -s -o "$TMP/grid-info.html" -w '%{http_code}' "$URL/helpers/blocks/grid-info")"
    assert_contains 'Demo Grid' "$(cat "$TMP/grid-info.html")"
}

test_an_address_outside_the_prefix_is_the_site_s() {
    built || return 0
    serving /helpers
    assert_contains '<title>Helpers FAQ' "$(curl -s "$URL/helpers-faq")"
}

test_with_a_prefix_where_the_grid_sets_no_helper_the_helpers_take_no_route() {
    built || return 0
    serving /w4os-helpers
    local page
    # The site's page of an address it does not have (Grav's error page), not a block of the helpers
    for page in w4os-helpers/blocks/grid-info helpers/blocks/grid-info; do
        page=$(curl -s "$URL/$page")
        assert_contains '<title>Error 404' "$page"
        assert_not_contains 'Demo Grid' "$page"
    done
}
