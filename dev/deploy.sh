#!/usr/bin/env bash
# Puts the site as it is in development on the dev server, in one command: the release zip of grav-plugin-w4os (with the engine
# and the helpers it bundles from their sibling projects), the package of the site, installed on the server, its cache emptied,
# then what runs there: the commits of the plugin, the engine, the helpers and the site.
#
#   dev/deploy.sh            the server is DEPLOY_HOST (an ssh host) of the .env of the project, its address DEPLOY_URL
#   dev/deploy.sh HOST       another one
#   W4OS_PLUGIN=DIR dev/deploy.sh   the plugin of another folder (a worktree of a branch)
#
# The server also gets the themes of dev/themes.txt (chosen on the settings page of the admin), never in the package.
#
# The plugin and the site are built from their last commit (build-tools refuses a tree with changes: commit first); the engine
# and the helpers as they are in their folders, so their commits are told with "+changes" when their tree is not clean.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
root="$PWD"

usage() { sed -n '2,10s/^# \{0,1\}//p' "$0"; }
[[ ${1:-} == -h || ${1:-} == --help ]] && { usage; exit 0; }
[ -f .env ] && { set -a; . ./.env; set +a; }
host=${1:-${DEPLOY_HOST:-}}
[ -n "$host" ] || { echo "deploy: no server (DEPLOY_HOST in .env, or dev/deploy.sh HOST)" >&2; exit 1; }
plugin="${W4OS_PLUGIN:-$root/../grav-plugin-w4os}"
[ -d "$plugin" ] || { echo "deploy: no grav-plugin-w4os next to this project" >&2; exit 1; }
# The package of the site takes the release zip of this plugin (packaging/build)
plugin=$(cd "$plugin" && pwd)
export W4OS_PLUGIN=$plugin

# A project's commit, "+changes" when its tree is not clean
commit() { echo "$(git -C "$1" log -1 --format=%h)$(git -C "$1" diff --quiet HEAD -- 2>/dev/null || echo +changes)"; }
# The folder a package of the plugin's vendor folder links to (a sibling project in development)
sibling() { (cd "$plugin/vendor/magicoli/$1" && pwd -P); }

(cd "$plugin" && rm -rf build && vendor/bin/build-tools build zip | tail -1)
# The package of the site from its last commit, as the opensim projects build theirs (build-tools refuses uncommitted changes)
[ -x vendor/bin/build-tools ] || { echo "deploy: build-tools is not installed: composer install" >&2; exit 1; }
vendor/bin/build-tools build deb | tail -1
deb=$(ls -t dist/w4os-site_*.deb | head -1)

scp -q "$deb" "$host:/tmp/"
# The package as it is built, whatever its version says against the one installed (another branch, an older commit)
# shellcheck disable=SC2029
ssh "$host" "sudo -n DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 apt-get install -y -qq --reinstall --allow-downgrades '/tmp/$(basename "$deb")' >/dev/null && rm -f '/tmp/$(basename "$deb")' &&
    sudo -n find /var/lib/opensim/www/cache -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
# The themes of development (dev/themes.txt), never in the package
dev/themes.sh | tail -1
# The themes of development in the site, as the web user that owns it
COPYFILE_DISABLE=1 tar --no-xattrs -C build/dev -cf - user | ssh "$host" "sudo -n -u www-data tar -xf - -C /var/lib/opensim/www && sudo -n find /var/lib/opensim/www/cache -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
# The site answers (DEPLOY_URL of the .env, its address)
[ -z "${DEPLOY_URL:-}" ] || echo "site answers: $(curl -s -o /dev/null -w '%{http_code}' "$DEPLOY_URL/")"

echo "on $host: plugin $(commit "$plugin"), engine $(commit "$(sibling opensim-engine)"), helpers $(commit "$(sibling opensim-helpers)"), site $(commit "$root")"
