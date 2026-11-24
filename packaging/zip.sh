# shellcheck shell=bash
# The site as a zip, sourced by packaging/build: the Grav tree of the package (a standard Grav site, the same the package installs
# in /var/lib/w4os/www), to unzip anywhere and configure, nothing to build or download.

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

# tree_digest DIR: the digest of what DIR holds (its files, by their path and content), the same for the same content wherever it is
tree_digest() {
    (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256) | shasum -a 256 | cut -c1-7
}

# bundled_suffix VERSION MANIFEST: what a development VERSION adds to tell the release zips of other projects it bundles (the
# plugin, with the engine and the helpers in it; MANIFEST: a line by zip, its path, its file, the digest of its content): .w and
# the distance and commit of each (.w535.g0da88a6), which sort after those of an earlier one, as the commits of the project do. A
# release (no +) bundles the releases its dependencies.txt names: nothing.
bundled_suffix() {
    local version=$1 manifest=$2 path file digest
    [[ $version == *+* && -s $manifest ]] || return 0
    while read -r path file digest; do
        file=${file%.zip}
        [[ $file != *+* ]] || printf '.w%s' "${file#*+}"
    done <"$manifest"
}

# bundled_version VERSION MANIFEST: VERSION with what it bundles (bundled_suffix)
bundled_version() {
    echo "$1$(bundled_suffix "$1" "$2")"
}
