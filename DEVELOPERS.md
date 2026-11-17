# Developers

The site is Grav, its official plugins and the w4os plugin, assembled at fixed versions into a Debian package. It holds no logic of its own: what a page does is the w4os plugin's (`grav-plugin-w4os`), what the grid does is the engine API's. What belongs here: the versions bundled, the theme, the default pages and settings, the installer, the package.

## Layout

- `dependencies.txt`: Grav, its plugins and the theme Quark2 at their tags; `grav-plugin-w4os` from its release zip (the newest of `../grav-plugin-w4os/dist/`, built there with `vendor/bin/build-tools build zip`), which carries the OpenSim engine and helpers: the package of the site depends on no OpenSim package.
- `theme/w4os`: the light theme, a child of Quark2 (Grav theme inheritance: the `theme://` stream looks in w4os, then in quark2): the name of the grid as logo, the main menu centered and on the right only the tools (`partials/theme-toggle.html.twig`: the languages, the menu of the visitor of the w4os plugin, day and night), its footer.
- `defaults/`: the settings (`config/`) and the pages (`pages/`, English and French) of a new site, copied to `/var/lib/w4os-site` by the postinst on first install only (an upgrade does not bring new defaults to an existing site).
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

Grav's code is read-only in `/usr/share/w4os-site/grav`; its `user/config`, `user/pages`, `user/accounts`, `user/data` are links to `/var/lib/w4os-site`, and `assets`, `images` to `/var/cache/w4os-site`. The plugins and the theme stay in the package (`user/plugins`, `user/themes`), so an upgrade brings their new versions.

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
