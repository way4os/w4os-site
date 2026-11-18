#!/usr/bin/env bash
# Prepares in build/dev what a server of development gets besides the package: the themes of dev/themes.txt in user/themes, the
# folder of the Grav root they go into (the theme is then chosen on the settings page of the admin of the site).
#
#   dev/themes.sh        build/dev/user/themes
set -Eeuo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
sources="$root/build/sources"
# shellcheck source=../packaging/sources.sh
source "$root/packaging/sources.sh"

rm -rf build/dev
mkdir -p build/dev/user/themes "$sources"
while read -r folder source ref; do
    [[ -n "$folder" && "$folder" != \#* ]] || continue
    extract "$source" "$ref" "build/dev/user/themes/$folder"
done < dev/themes.txt
echo "build/dev: $(ls build/dev/user/themes | wc -l | tr -d ' ') themes"
