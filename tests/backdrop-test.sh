#!/usr/bin/env bash
# The backdrop of the site (the w4os plugin's), end to end, at the root and under a prefix: a picture of each of the theme's series
# behind its pages, the light one and the dark one, as Grav serves them (webp, jpeg); none on the viewer's welcome page.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

set_up_before_script() {
    site_set_up
    serve_prefixed
}

# backdrop PAGE MODE FORMAT: the address of the picture of MODE in the style of PAGE, in FORMAT
backdrop() {
    grep -o -- "--w4os-backdrop-$2:image-set([^;}]*" <<<"$1" | head -1 | grep -o "url(\"[^\"]*\.$3\")" | sed 's/^url("//; s/")$//'
}

test_the_theme_has_a_series_of_pictures_for_each_mode_web_sized_their_names_kept() {
    local folder="$ROOT/theme/w4os/images/backdrop" file width
    assert_equals "midi-legacy.jpg midi.jpg shared-13h17.jpg shared-13h20.jpg" "$(LC_ALL=C ls "$folder/light" | xargs)"
    assert_equals "aube.jpg crepuscule.jpg minuit.jpg" "$(LC_ALL=C ls "$folder/dark" | xargs)"
    for file in "$folder"/*/*.jpg; do
        width=$(php -r 'echo getimagesize($argv[1])[0];' "$file")
        assert_equals 2048 "$width"
        assert_less_than 200000 "$(wc -c <"$file")"
    done
}

test_the_pages_show_a_picture_of_each_mode_behind_them_as_grav_serves_it() {
    built || return 0
    local base page origin mode format address
    for base in "$URL" "$PREFIXED"; do
        page=$(curl -s "$base/help")
        origin=$(sed -E 's#^(https?://[^/]+).*#\1#' <<<"$base")
        assert_matches '<body [^>]*class="([^"]* )?w4os-backdrop[ "]' "$page"
        for mode in light dark; do
            for format in webp jpg; do
                address=$(backdrop "$page" $mode $format)
                # A picture of the theme's series for the mode, from Grav's images under the prefix of the site
                assert_matches "^${base#"$origin"}/images/.*-(midi|midi-legacy|shared-13h17|shared-13h20|aube|crepuscule|minuit)\.$format$" "$address"
                assert_equals "200 image/$([ $format = jpg ] && echo jpeg || echo webp)" \
                    "$(curl -s -o /dev/null -w '%{http_code} %{content_type}' "$origin$address")"
            done
        done
        assert_matches '-(aube|crepuscule|minuit)\.webp$' "$(backdrop "$page" dark webp)"
        assert_matches '-(midi|midi-legacy|shared-13h17|shared-13h20)\.webp$' "$(backdrop "$page" light webp)"
    done
}

test_a_page_a_viewer_shows_has_none_whatever_the_page() {
    built || return 0
    local agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) SecondLife/7.1.11.15094 (Firestorm) Safari/537.36'
    local base path page
    for base in "$URL" "$PREFIXED"; do
        for path in / /about; do
            page=$(curl -sL -A "$agent" "$base$path")
            assert_contains '</html>' "$page"
            assert_not_contains 'w4os-backdrop' "$page"
            assert_not_contains '/images/backdrop/' "$page"
        done
    done
}

test_the_welcome_page_of_the_viewer_has_none() {
    built || return 0
    assert_not_contains 'w4os-backdrop' "$(curl -s "$URL/welcome")"
}

test_the_picture_shows_behind_the_page_with_no_card_around_its_content() {
    local css
    css=$(cat "$ROOT/theme/w4os/css/custom.css")
    # Quark2's canvas and footer see-through; no card, no veil: the boxes of the page alone stand out
    assert_contains 'body.w4os-backdrop #body-wrapper, body.w4os-backdrop #footer { background: transparent; }' "$css"
    assert_not_contains 'w4os-glass' "$css"
    assert_not_contains 'backdrop-filter' "$css"
    assert_contains "{{ w4os_backdrop|default(false) ? ' w4os-backdrop' }}" "$(cat "$ROOT/theme/w4os/templates/partials/base.html.twig")"
}
