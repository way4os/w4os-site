# Developers

The site is Grav, its official plugins and the w4os plugin, assembled at fixed versions into a Debian package. It holds no logic of its own: what a page does is the w4os plugin's (`grav-plugin-w4os`), what the grid does is the engine API's. What belongs here: the versions bundled, the theme, the default pages and settings, the installer, the package.

## Layout

- `dependencies.txt`: Grav, its plugins and the theme Quark2 at their tags; `grav-plugin-w4os` from the sibling folder `../grav-plugin-w4os` at `HEAD` while it has no release (its committed tree only).
- `theme/w4os`: the light theme, a child of Quark2 (Grav theme inheritance: the `theme://` stream looks in w4os, then in quark2): the name of the grid as logo, its footer, a few styles.
- `defaults/`: the settings (`config/`) and the pages (`pages/`, English and French) of a new site, copied to `/var/lib/w4os-site` by the postinst on first install only.
- `grav.env`: the `.env` of Grav in the package, which puts its caches, logs, tmp and backups out of the code.
- `bin/w4os-site`: the installer (bash, with the functions of bash-tools): `setup`, `status`, `web`.
- `web/apache.conf`: the Apache template of `w4os-site web apache`; Caddy and nginx come from Grav's own `webserver-configs`.
- `packaging/`: the nfpm definition, `build` (assembles `build/w4os-site`), the maintainer scripts.

## The package

Grav's code is read-only in `/usr/share/w4os-site/grav`; its `user/config`, `user/pages`, `user/accounts`, `user/data` are links to `/var/lib/w4os-site`, and `assets`, `images` to `/var/cache/w4os-site`. The plugins and the theme stay in the package (`user/plugins`, `user/themes`), so an upgrade brings their new versions.

```bash
/opt/magic/apt-repo/bin/apt-package     # build: packaging/build, then nfpm, into dist/
```

`packaging/build` clones each dependency at its tag into `build/sources`, extracts its committed tree, and installs the composer dependencies of what does not ship them. Nothing is enabled in a web server by installing the package.

## Tests

```bash
lib/bashunit/bashunit tests/
```

The installer is tested on a site in a temporary folder (`W4OS_SITE_DATA`, `W4OS_SITE_SHARE`, `W4OS_SITE_OWNER`, `W4OS_SITE_CACHE` point it there), against a fake engine API (`tests/fixtures/api.php`, PHP built-in server).

The site itself is tried on a development machine, never on a live grid: install the package there, `w4os-site setup` with the helpers of a test grid, `w4os-site web apache --port <port> --install`. No real mail: addresses of `example.org`, and the tokens taken from the API with `send: false`.
