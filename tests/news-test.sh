#!/usr/bin/env bash
# The news of the default site (defaults/pages/03.news): its page lists its posts, the last first, a "Hello world" one to begin
# with; the home page of the grid shows the last ones (the w4os plugin); each page in every language of the site.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

test_every_page_of_the_news_is_in_every_language_of_the_site() {
    local page lang missing=
    for page in "$ROOT"/defaults/pages/03.news/blog.md "$ROOT"/defaults/pages/03.news/*/*/*/item.md; do
        for lang in fr de it nl pt-BR cy; do
            [ -f "${page%.md}.$lang.md" ] || missing="$missing ${page#"$ROOT"/} $lang"
        done
    done
    assert_empty "$missing"
}

test_the_news_page_lists_its_posts_the_home_page_the_last_ones() {
    built || return 0
    assert_contains 'Hello world' "$(curl -s "$URL/news")"
    assert_contains 'Bonjour le monde' "$(curl -s "$URL/fr/news")"
    local home
    home=$(curl -s "$URL/")
    assert_contains 'class="w4os-latest"' "$home"
    assert_contains '>Hello world</a></h4>' "$home"
}

test_the_date_of_a_post_is_written_the_way_the_language_of_the_page_writes_it() {
    built || return 0
    assert_contains '21 nov' "$(curl -s "$URL/fr/news")"
    assert_contains 'Nov 21, 2026' "$(curl -s "$URL/news")"
}
