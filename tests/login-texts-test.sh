#!/usr/bin/env bash
# The texts of the Login plugin in every language of the suite: the ones it lacks given by the w4os plugin (its languages,
# PLUGIN_LOGIN), never one it has, each with the placeholders of its English; on the site, a French page says them in French.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

# login_texts: for each language of the suite, the keys of the Login plugin the w4os plugin gives that it has too, the keys
# neither gives, and the ones whose placeholders differ from the English (nothing when all is right)
login_texts() {
    php -r '
        require $argv[1]."/vendor/autoload.php";
        $read = fn (string $file, string $root) => is_file($file) ? (array) (Symfony\Component\Yaml\Yaml::parseFile($file)[$root] ?? []) : [];
        $marks = function (string $text): array {
            preg_match_all("/%(?:\d+\\$)?[sd]|\{\{[^}]*\}\}|<[a-z][^>]*>/i", $text, $m);
            sort($m[0]);

            return $m[0];
        };
        $en = $read($argv[1]."/user/plugins/login/languages/en.yaml", "PLUGIN_LOGIN");
        foreach (["fr", "de", "it", "nl", "pt-BR", "cy"] as $lang) {
            $own = $read($argv[1]."/user/plugins/login/languages/$lang.yaml", "PLUGIN_LOGIN");
            $given = $read($argv[1]."/user/plugins/w4os/languages/$lang.yaml", "PLUGIN_LOGIN");
            foreach (array_keys(array_intersect_key($given, $own)) as $key) {
                echo "$lang: $key given again\n";
            }
            foreach (array_keys(array_diff_key($en, $own, $given)) as $key) {
                echo "$lang: $key missing\n";
            }
            foreach ($given as $key => $text) {
                isset($en[$key]) && $marks((string) $text) !== $marks((string) $en[$key]) && print("$lang: $key placeholders\n");
            }
        }
    ' "$GRAV_TREE"
}

test_the_texts_the_login_plugin_lacks_are_given_never_one_it_has_each_with_its_placeholders() {
    built || return 0
    assert_empty "$(login_texts)"
}

test_a_french_page_says_the_texts_of_the_login_plugin_in_french_its_own_and_the_ones_given() {
    built || return 0
    local jar=$TMP/fr i nonce page own given
    own=$(php -r 'require $argv[1]."/vendor/autoload.php"; echo Symfony\Component\Yaml\Yaml::parseFile($argv[1]."/user/plugins/login/languages/fr.yaml")["PLUGIN_LOGIN"]["LOGIN_FAILED"];' "$GRAV_TREE")
    given=$(php -r 'require $argv[1]."/vendor/autoload.php"; echo sprintf(Symfony\Component\Yaml\Yaml::parseFile($argv[1]."/user/plugins/w4os/languages/fr.yaml")["PLUGIN_LOGIN"]["TOO_MANY_LOGIN_ATTEMPTS_RETRY"], 10);' "$GRAV_TREE")
    for i in 1 2 3 4 5 6; do
        nonce=$(curl -s -c "$jar" -b "$jar" "$URL/fr/login" | sed -n 's/.*name="login-form-nonce" value="\([^"]*\)".*/\1/p' | head -1)
        page=$(curl -s -L -c "$jar" -b "$jar" "$URL/fr/login" --data-urlencode "username=Nobody Here" --data-urlencode "password=wrong" \
            -d "task=login.login" --data-urlencode "login-form-nonce=$nonce")
        # A text the Login plugin translates: its own
        [ "$i" -gt 1 ] || assert_contains "$own" "$page"
    done
    # One it does not: the w4os plugin's
    assert_contains "$given" "$page"
    assert_not_contains 'Too many failed login attempts' "$page"
}
