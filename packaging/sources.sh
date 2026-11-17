# shellcheck shell=bash
# The sources the package bundles (dependencies.txt), sourced by packaging/build: their trees at a ref, or some files of them.
# $sources is the folder where the repositories are kept between builds.

# The committed tree of a source at a ref, extracted into a folder
extract() {
    local source=$1 ref=$2 target=$3 repo
    repo=$(repository "$source" "$ref" '')
    mkdir -p "$target"
    git -C "$repo" archive --format=tar "$ref" | tar -x -C "$target"
}

# Some files or folders of a source at a ref, each put at its place in a folder: from=to, relative to the source and the folder
pick() {
    local source=$1 ref=$2 target=$3 repo pair from to tmp
    shift 3
    repo=$(repository "$source" "$ref" "--filter=blob:none --no-checkout")
    tmp=$(mktemp -d)
    for pair in "$@"; do
        from=${pair%%=*} to=${pair#*=}
        git -C "$repo" archive --format=tar "$ref" -- "$from" | tar -x -C "$tmp"
        mkdir -p "$(dirname "$target/$to")"
        rm -rf "${target:?}/$to"
        mv "$tmp/$from" "$target/$to"
    done
    rm -rf "$tmp"
}

# The repository of a source: the folder of a sibling project, else a clone kept in $sources (a tag or a branch at once; a commit
# with the whole history). A filter (--filter=blob:none) leaves out the contents of the files not taken.
repository() {
    local source=$1 ref=$2 filter=$3 repo
    # shellcheck disable=SC2086
    if [ -d "$source" ]; then
        echo "$source"
        return
    fi
    repo="$sources/$(basename "$source" .git)-$ref"
    [ -d "$repo/.git" ] || git -c advice.detachedHead=false clone -q --depth 1 $filter --branch "$ref" "$source" "$repo" 2>/dev/null ||
        git clone -q "$source" "$repo"
    echo "$repo"
}
