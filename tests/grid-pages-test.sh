#!/usr/bin/env bash
# The pages a grid names in its grid info (welcome, about, password), end to end: each answers, at the root of the site and under a
# prefix (/opensim, as a grid info gives them for a site there), never a 404.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

set_up_before_script() {
    site_set_up
    serve_prefixed
}

# page BASE PATH: the page, its code on its last line
page() {
    curl -s -w '\n%{http_code}' "$1$2"
}

test_welcome_is_the_page_a_viewer_shows_before_the_login_alone_without_the_theme_of_the_site() {
    built || return 0
    local base welcome
    for base in "$URL" "$PREFIXED"; do
        welcome=$(page "$base" /welcome)
        assert_equals 200 "$(tail -1 <<<"$welcome")"
        # The page alone (no top bar, no menu of the site), as the helpers' splash: what the grid is beside the title of the site
        # and its popular places (the blocks of the helpers, which this test does not serve)
        assert_contains 'class="w4os-viewer viewer w4os-welcome"' "$welcome"
        assert_not_contains '<nav' "$welcome"
        assert_contains 'class="layout with-sidebars"' "$welcome"
        assert_contains '<h1>My grid</h1>' "$welcome"
        assert_contains 'w4os-helpers/assets/css/page.css' "$welcome"
    done
}

test_about_is_a_page_of_the_site() {
    built || return 0
    local base about
    for base in "$URL" "$PREFIXED"; do
        about=$(page "$base" /about)
        assert_equals 200 "$(tail -1 <<<"$about")"
        assert_contains '<title>About | My grid' "$about"
    done
    # In the languages of the site
    assert_contains '<title>À propos | My grid' "$(page "$URL" /fr/about)"
    assert_contains '<title>Über uns | My grid' "$(page "$PREFIXED" /de/about)"
}

test_password_is_the_page_of_a_lost_password_of_the_site() {
    built || return 0
    local base password
    for base in "$URL" "$PREFIXED"; do
        password=$(page "$base" /password)
        assert_equals 200 "$(tail -1 <<<"$password")"
        assert_contains 'name="__form-name__" value="w4os-forgot"' "$password"
    done
    # Its own address still the site's (its links, its mails)
    assert_equals 200 "$(tail -1 <<<"$(page "$PREFIXED" /forgot_password)")"
}

test_the_help_links_to_the_pages_of_the_site_under_its_prefix() {
    built || return 0
    local help
    help=$(page "$PREFIXED" /help)
    assert_equals 200 "$(tail -1 <<<"$help")"
    assert_contains 'href="/opensim/register"' "$help"
    assert_contains 'href="/opensim/forgot_password"' "$help"
    # Every language of the site has it
    local lang
    for lang in fr de it nl pt-BR cy; do
        assert_equals 200 "$(curl -s -o /dev/null -w '%{http_code}' -L "$PREFIXED/$lang/help")"
    done
}
