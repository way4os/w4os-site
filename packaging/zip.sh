# shellcheck shell=bash
# The site as a zip, sourced by packaging/build: the Grav tree of the package (a standard Grav site, the same the package installs
# in /var/lib/opensim/www), to unzip anywhere and configure, nothing to build or download.

# site_zip GRAV DEFAULTS ZIP: the tree of GRAV as w4os-site/ in ZIP, with the config and pages of DEFAULTS
site_zip() {
    local grav=$1 defaults=$2 zip=$3 stage
    stage=$(mktemp -d)
    site_tree "$grav" "$defaults" "$stage/w4os-site"
    mkdir -p "$(dirname "$zip")"
    zip="$(cd "$(dirname "$zip")" && pwd)/$(basename "$zip")"
    rm -f "$zip"
    # zip follows the links that remain (inside the tree): the files they point to are stored
    (cd "$stage" && zip -qr "$zip" w4os-site)
    rm -rf "$stage"
}

# site_tree GRAV DEFAULTS DIR: the tree of the zip in DIR
site_tree() {
    cp -R "$1" "$3"
    standard_tree "$3" "$2"
}

# standard_tree DIR DEFAULTS: DIR a standard Grav site: the config and pages of DEFAULTS where it has none, the folders Grav writes
standard_tree() {
    local site=$1 defaults=$2 dir
    rm -f "$site/.env"
    for dir in config pages; do
        [ -d "$site/user/$dir" ] || cp -R "$defaults/$dir" "$site/user/$dir"
    done
    for dir in user/accounts user/data user/data/sessions assets images cache tmp logs backup; do
        mkdir -p "$site/$dir"
    done
}
