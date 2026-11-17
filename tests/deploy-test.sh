#!/usr/bin/env bash
# dev/deploy.sh without a server: its help, and a refusal that names what is missing. It never reaches a server here.

set_up() {
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    WORK=$(mktemp -d)
    cp -R "$ROOT/dev" "$WORK/dev"
}

tear_down() {
    rm -rf "$WORK"
}

test_help_tells_how_to_use_it() {
    assert_contains "DEPLOY_HOST" "$("$WORK/dev/deploy.sh" --help)"
}

test_no_server_is_refused() {
    local output
    output=$(DEPLOY_HOST= "$WORK/dev/deploy.sh" 2>&1) && fail "it should refuse"
    assert_contains "no server" "$output"
}
