#!/usr/bin/env bash
# What a page asks the helpers of the grid for its blocks, and how long it waits for them, end to end, the helpers a fake that
# logs each block it gives (tests/fixtures/helpers.php): a page asks a block once, all its blocks at once; a copy past its time is
# shown at once; helpers that do not answer cost the time a block is waited for, once.

# shellcheck source=site.sh
source "$(dirname "${BASH_SOURCE[0]}")/site.sh"

VIEWER='Mozilla/5.0 (Windows; U; Windows NT 10.0; en-US) AppleWebKit/538.1 (KHTML, like Gecko) Firestorm/7.1.11.76496 (Firestorm-Releasex64) Safari/538.1'

set_up_before_script() {
    site_set_up
    serve_helpers
    serve_fastcgi
    serve_apache
}

# cold DELAY: no block kept by the site in English (Grav's own cache made again by the French pages), the helpers answering each
# block after DELAY ms, their log empty
cold() {
    rm -rf "${SITE:?}/cache/"*
    echo 0 >"$HELPERS/delay"
    curl -s -o /dev/null -L "$URL/fr/"
    curl -s -o /dev/null -L "$URL/fr/profile/Ada.Love"
    echo "$1" >"$HELPERS/delay"
    : >"$HELPERS/log"
}

# timed URL [USER_AGENT]: the time the page took (seconds), its body in $TMP/page
timed() {
    curl -s -L -o "$TMP/page" -A "${2:-Mozilla/5.0}" -w '%{time_total}' "$1"
}

# under SECONDS TIME: whether TIME is under SECONDS
under() {
    awk -v limit="$1" -v time="$2" 'BEGIN { exit !(time < limit) }'
}

test_a_page_in_a_viewer_asks_its_block_once() {
    built || return 0
    cold 0
    curl -s -o /dev/null -A "$VIEWER" "$URL/search"
    assert_equals 'search viewer' "$(cat "$HELPERS/log")"
}

test_a_page_asks_its_blocks_all_at_once_and_shows_them_in_their_order() {
    built || return 0
    cold 1500
    local time
    time=$(timed "$URL/")
    # Five blocks of 1.5 s: the slowest one, not the sum
    assert_successful_code "$(under 2.5 "$time")"
    assert_equals 5 "$(wc -l <"$HELPERS/log" | tr -d ' ')"
    assert_equals 'fake-popular_places fake-destination_guide fake-grid-info fake-grid-status fake-motd' \
        "$(grep -o 'fake-block fake-[a-z_-]*' "$TMP/page" | cut -d' ' -f2 | tr '\n' ' ' | sed 's/ $//')"
}

test_a_copy_past_its_time_is_shown_at_once_without_a_server_that_closes_the_connection_first_kept_its_day() {
    built || return 0
    cold 0
    curl -s -o /dev/null -L "$URL/"
    echo 1500 >"$HELPERS/delay"
    : >"$HELPERS/log"
    sleep 2
    local time
    time=$(timed "$URL/")
    assert_successful_code "$(under 1 "$time")"
    assert_contains 'fake-block fake-motd' "$(cat "$TMP/page")"
    # PHP's built-in server cannot close the connection before the page's end: the copy is not asked again
    sleep 2
    assert_empty "$(cat "$HELPERS/log")"
}

# past_its_time SERVER: a copy past its time shown at once by SERVER, two pages at once, then read again after the page is sent,
# each block by one page alone
past_its_time() {
    cold 0
    curl -s -o /dev/null -L "$1/"
    echo 1500 >"$HELPERS/delay"
    : >"$HELPERS/log"
    sleep 2
    local time
    time=$(timed "$1/")
    curl -s -o /dev/null -L "$1/" &
    assert_successful_code "$(under 1 "$time")"
    assert_contains 'fake-block fake-motd' "$(cat "$TMP/page")"
    sleep 3
    assert_equals 'destination_guide grid-info grid-status motd popular_places' "$(cut -d' ' -f1 "$HELPERS/log" | sort | tr '\n' ' ' | sed 's/ $//')"
}

test_a_copy_past_its_time_is_shown_at_once_and_read_again_after_the_page_is_sent_once_for_two_pages_with_php_fpm() {
    built || return 0
    if [ -z "${FASTCGI:-}" ]; then
        bashunit::skip "no php-fpm or caddy"
        return
    fi
    past_its_time "$FASTCGI"
}

test_a_copy_past_its_time_is_shown_at_once_and_read_again_after_the_page_is_sent_once_for_two_pages_with_apache_and_mod_php() {
    built || return 0
    if [ -z "${APACHE:-}" ]; then
        bashunit::skip "no podman or no image of Grav (docker.io/getgrav/grav:php8.4)"
        return
    fi
    past_its_time "$APACHE"
}

test_helpers_that_do_not_answer_are_waited_for_once_a_short_while_then_said_at_once() {
    built || return 0
    # Last: the helpers answer the profile 6 s later, after the test
    cold 6000
    local first second
    first=$(timed "$URL/profile/Ada.Love")
    assert_contains 'Timeout · helpers: profile' "$(cat "$TMP/page")"
    second=$(timed "$URL/profile/Ada.Love")
    assert_contains 'Timeout · helpers: profile' "$(cat "$TMP/page")"
    # Waited for 3 s, once
    assert_successful_code "$(under 4.5 "$first")"
    assert_general_error "$(under 2.5 "$first")"
    assert_successful_code "$(under 1 "$second")"
}
