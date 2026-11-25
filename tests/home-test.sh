#!/usr/bin/env bash
# The home page of the site, end to end, at the root and under a prefix: what the grid is (its info, its status) in one aside, its
# message of the day (a welcome title) and the Connect block in the other, with the news, the text in the middle (one column on a narrow screen: the
# container queries of the plugin's css/w4os.css).

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

set_up_before_script() {
    site_set_up
    serve_prefixed
}

test_the_home_page_has_what_the_grid_is_on_one_side_its_message_of_the_day_and_how_to_connect_on_the_other() {
    built || return 0
    local base home grid news
    for base in "$URL" "$PREFIXED"; do
        home=$(curl -s "$base/")
        grid=$(sed -n '/<aside class="w4os-home-grid">/,/<aside class="w4os-home-news">/p' <<<"$home")
        news=$(sed -n '/<aside class="w4os-home-news">/,$p' <<<"$home")
        assert_contains '<aside class="w4os-home-grid">' "$grid"
        assert_not_contains 'w4os-start-steps' "$grid"
        assert_contains 'w4os-start-steps' "$news"
    done
    # The theme extends the plugin's home, as w4os.org's does, rather than copying it
    assert_contains "{% extends '@w4os/w4os/home.html.twig' %}" "$(cat "$ROOT/theme/w4os/templates/w4os/home.html.twig")"
}

test_its_message_of_the_day_and_the_connect_block_come_with_the_news_what_the_grid_is_on_the_other_side() {
    local tree=${W4OS_SITE_BUILD:-$ROOT/build/w4os-site/grav}
    [ -f "$tree/vendor/autoload.php" ] || { bashunit::skip "the site is not built"; return; }
    # The theme's home as the built site has it, over the plugin's, its blocks stubbed (the test site has no grid to fill them)
    local home
    home=$(php -r '
        require $argv[1];
        $loader = new Twig\Loader\FilesystemLoader([$argv[2] . "/user/themes/w4os/templates", $argv[2] . "/user/plugins/w4os/templates"]);
        $loader->addPath($argv[2] . "/user/plugins/w4os/templates", "w4os");
        $twig = new Twig\Environment($loader);
        $twig->addFunction(new Twig\TwigFunction("w4os_block", fn (string $name) => "<section class=\"block block-$name\"></section>", ["is_safe" => ["html"]]));
        $twig->registerUndefinedFunctionCallback(fn (string $name) => new Twig\TwigFunction($name, fn () => null));
        $twig->registerUndefinedFilterCallback(fn (string $name) => new Twig\TwigFilter($name, fn ($value) => $value));
        echo str_replace("\n", " ", $twig->render("w4os/home.html.twig", ["content" => ""]));
    ' "$tree/vendor/autoload.php" "$tree")
    assert_matches '<aside class="w4os-home-grid">.*block-grid-info.*block-grid-status.*<aside class="w4os-home-news">.*block-motd.*w4os-start' "$home"
    assert_equals 1 "$(grep -o 'block-motd' <<<"$home" | wc -l | tr -d ' ')"
}
