# shellcheck shell=bash
# The site as a zip, sourced by packaging/build: the Grav tree of the package, to unzip anywhere and configure, nothing to build
# or download. The folders the package keeps in /var/lib and /var/cache are folders of the tree, the content of a new site in
# them (the defaults); the .env that sends Grav's writes there is left out; the links inside the tree become the files they are.

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

# site_tree GRAV DEFAULTS DIR: the tree of the zip in DIR, its links inside the tree left as they are
site_tree() {
    local grav=$1 defaults=$2 site=$3 dir
    cp -R "$grav" "$site"
    rm -f "$site/.env"
    for dir in user/config user/pages user/accounts user/data assets images; do
        rm -f "$site/$dir"
    done
    cp -R "$defaults/config" "$site/user/config"
    cp -R "$defaults/pages" "$site/user/pages"
    for dir in user/accounts user/data user/data/sessions assets images cache tmp logs backup; do
        mkdir -p "$site/$dir"
    done
}
