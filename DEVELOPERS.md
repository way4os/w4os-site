# Developers

The site is Grav, its official plugins and the w4os plugin, assembled at fixed versions into a Debian package. It holds no logic of its own: what a page does is the w4os plugin's (`grav-plugin-w4os`), what the grid does is the engine API's. What belongs here: the versions bundled, the theme, the default pages and settings, the installer, the package.

## Layout

- `dependencies.txt`: Grav, its plugins and the theme Quark2 at their tags; `grav-plugin-w4os` from its release zip (the newest of `../grav-plugin-w4os/dist/`, built there with `vendor/bin/build-tools build zip`), which carries the OpenSim engine and helpers: the package of the site depends on no OpenSim package.
- `dependencies-grav17.txt`: what the package ships instead for PHP older than 8.3 (Debian 12), in `/usr/share/w4os-site/site-grav17`: Grav 1.7 and Quark2 1.1.12, its last version for Grav 1.7. `bin/w4os-site-tree` puts these units where the PHP of the site is older than 8.3, and the seed's once it is newer; the plugins are the same on both. `tests/tree-test.sh` covers the choice; the whole site is checked on both lines in containers (debian:bookworm, debian:trixie).
- `theme/w4os`: the light theme, a child of Quark2 (Grav theme inheritance: the `theme://` stream looks in w4os, then in quark2): the name of the grid as logo, the main menu centered and on the right only the tools (`partials/theme-toggle.html.twig`: the languages, the menu of the visitor of the w4os plugin, day and night), its footer.
- `defaults/`: the settings (`config/`) and the pages (`pages/`, English and French) of a new site, in the tree of the site (`user/config`, `user/pages`) by `packaging/build` (an upgrade does not bring new defaults to an existing site).
- `grav.env`: the `.env` of Grav in the package, which puts its caches, logs, tmp and backups out of the code.
- `bin/w4os-site`: the installer (bash, with the functions of bash-tools): `setup`, `status`, `web`.
- `web/apache.conf`: the Apache template of `w4os-site web apache`; Caddy and nginx come from Grav's own `webserver-configs`.
- `packaging/`: the nfpm definition, `build` (assembles `build/w4os-site`), `build-zip` (the zip of that tree, `zip.sh`), the maintainer scripts.

## The zip and the package

They are built as the opensim projects build theirs, by build-tools and its apt-package (`composer install` first, for `vendor/bin/build-tools`), from the last commit, into `dist/`: the zip `w4os-site-<version>.zip`, the general delivery, and the Debian package `w4os-site_<version>_all.deb`; the version is the one of `.version`, with the number of commits and the hash of HEAD until a tag. `build-tools release` attaches both to the GitHub release.

```bash
dev/build.sh                            # the zip and the package (build-tools build)
vendor/bin/build-tools build zip        # the zip only: packaging/build-zip
dev/release.sh                          # the release (build-tools release): tag, build, GitHub release, apt repository
```

build-tools comes from `../build-tools` (composer path repository, as for opensim-cli).

The zip is the Grav tree of the package with its writable folders inside (the defaults of a new site in `user/config` and `user/pages`), no link outside and no `.env`: it is unzipped anywhere and configured.

The package ships the same tree as its seed, `/usr/share/w4os-site/site`, never served. Its postinst runs `bin/w4os-site-tree configure`: a new site is the seed copied to `/var/lib/w4os/www`, the web user's (a site of before, `/usr/share/w4os-site/grav` and `/var/lib/w4os-site`, moved into it); an existing site gets, unit by unit (Grav, each plugin, each theme, each default page), what the seed has where the site still has the files the package put, as the manifest (`user/data/w4os-site/manifest`) records them, and keeps the rest; a new default page is added unless the site has a page at its route. A site of before the pages were units (no page in its manifest) gets the new text of a default page it has as one of the versions of the package gave it: `packaging/build` writes the texts of every version of `defaults/pages` from git (`/usr/share/w4os-site/pages-history`, path and checksum). `tests/tree-test.sh` runs it in a temporary folder.

`packaging/build` clones each dependency at its tag into `build/sources`, extracts its committed tree, and installs the composer dependencies of what does not ship them. Nothing is enabled in a web server by installing the package.

## The dev server

```bash
dev/deploy.sh                             # the server of DEPLOY_HOST in .env (see .env.example), or dev/deploy.sh HOST
```

It builds the release zip of `grav-plugin-w4os` (from its last commit, with the engine and the helpers of the sibling folders as they are), then the package of the site, installs it on the server with `apt-get`, empties the cache of the site, and tells the commits of the plugin, the engine, the helpers and the site that run there. Run it again whenever one of them changed: the server has only what its last deploy bundled. A branch of the plugin in a worktree: `W4OS_PLUGIN=../grav-plugin-w4os-<branch> dev/deploy.sh`; the engine and the helpers bundled are the ones the plugin's vendor folder links to, the sibling folders.

## Tests

```bash
lib/bashunit/bashunit tests/
```

The installer is tested on a site in a temporary folder (`W4OS_SITE_DATA`, `W4OS_SITE_SHARE`, `W4OS_SITE_OWNER`, `W4OS_SITE_CACHE` point it there), against a fake engine API (`tests/fixtures/api.php`, PHP built-in server).

Signing in and staying signed in are tested end to end (`tests/remember-test.sh`): the Grav tree built (`build/w4os-site/grav`, or `W4OS_SITE_BUILD`) set up as the zip has it in a temporary folder, served by PHP alone with several workers, its engine the same fake API; each cookie jar of curl is a browser. Skipped while no tree is built, or while the tree is older than the code it is made of (the plugin next to this project or `W4OS_PLUGIN`, w4os-views, the theme: the test names which): a run that passes is the code of now. `W4OS_TEST_KEEP=1` leaves the site and its logs.

The site itself is tried on a development machine, never on a live grid: install the package there, `w4os-site setup` with the helpers of a test grid, `w4os-site web apache --port <port> --install`. No real mail: addresses of `example.org`, and the tokens taken from the API with `send: false`.

## A grid to try the standalone site

The site on its own, from this folder (`php -S`, as the tests do), its bundled engine and helpers reaching a running grid over the
network: `W4OS_STANDALONE_GRID=friendly_fowl lib/bashunit/bashunit tests/standalone-test.sh`. A test shortcut gives it the config
of the grid: `/etc/opensim` of this machine is a mirror of the one of the grid's machine (a real remote install would get what lives
in the ini files from the grid's engine API). Refresh it (read-only on the grid's side, readable by its owner alone here):

```bash
rsync -a --delete --chmod=go-rwx --rsync-path="sudo -n rsync" -e ssh "$DEPLOY_HOST:/etc/opensim/" /etc/opensim/
```

The database is reached at `W4OS_STANDALONE_DB` (host:port, the grid's machine by default): its server must listen on the network
and grant the site's user from this machine. The pictures need PHP `imagick` with JPEG 2000 (OpenJPEG).
