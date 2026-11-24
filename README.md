# w4os site

The light website of an [OpenSimulator](http://opensimulator.org) grid, installable by anyone on any server: avatars register with a model and confirm their email, sign in, manage their account and their password; the managers of the grid manage the avatars; Markdown pages show the blocks of the helpers (grid info, grid status, search, profile...). It talks to the OpenSim engine API of the grid, which does everything.

It is [Grav](https://getgrav.org) with the [w4os plugin](https://github.com/magicoli/grav-plugin-w4os), a light theme and default pages, in one Debian package. For the full application, see w4os-app (later); to add the same pages to an existing Grav or WordPress site, use the w4os plugin of that site.

## Requirements

- A Debian or Ubuntu server with PHP 8.2 or newer and a web server (Apache, Caddy or nginx; PHP-FPM recommended): Debian 12, Debian 13,
  Ubuntu 24.04, Ubuntu 26.04. With PHP 8.2 (Debian 12) the package gives the site Grav 1.7, with 8.3 or newer Grav 2; the zip needs
  PHP 8.3 or newer. Grav 1.7 is kept until PHP 8.3's end of life at the latest (31 December 2027), see the plugin's ROADMAP.
- An OpenSimulator grid, on this machine or another one: with its engine API (w4os-engine) and an API key for the site, or with its Robust database reachable from the site (the w4os plugin carries the engine and the helpers: no OpenSim package is needed on the server of the site).

## Install

### The zip, anywhere

The site as a zip (`w4os-site-<version>.zip`, on the release): Grav, its plugins, the theme, Font Awesome and the defaults of a new site, nothing to build or download.

1. Unzip it where the web server serves it (`unzip w4os-site-<version>.zip -d /var/www/`), and give the web server the folders it writes: `user/config`, `user/pages`, `user/accounts`, `user/data` (with `user/data/sessions`, the sessions), `assets`, `images`, `cache`, `tmp`, `logs` and `backup` of `w4os-site/`.
2. Point the web server at `w4os-site/` (the configurations Grav gives are in `webserver-configs/`), with PHP 8.3 or later (Grav 2) and its extensions curl, gd, mbstring, xml, zip, intl and imagick (with ImageMagick's OpenJPEG delegate, `libopenjp2-7` on Debian, for the JPEG 2000 pictures of the grid; pdo_mysql too, for the engine bundled with the plugin).
3. Connect it to the grid in `user/config/plugins/w4os.yaml`: `engine: remote`, `api_url` (the engine API, `https://grid.example.org/api`), `url` (the helpers, for the blocks) and `grid`; the API key of the site (`opensim api-key create w4os-site`, on the machine of the grid) in `user/data/w4os/api.json`, `{"api_key": "osk_..."}`, readable by the web server only. With Grav's admin, the settings page of the plugin does both.

To try it on a computer: `php -S localhost:8000 system/router.php` in `w4os-site/`.

### Debian, with apt

On Debian and Ubuntu, the package installs the same site, a standard Grav site in `/var/lib/w4os/www` that the web server's user owns, and Grav's own tools (GPM, the admin) update like any other:

```bash
sudo apt install w4os-site            # or: sudo apt install ./w4os-site_<version>_all.deb
sudo w4os-site setup                  # asks the address of the helpers and the API key
sudo w4os-site web apache --host grid.example.org --install
```

- `setup` connects the site to the API of the grid (the bundled engine is set in `/var/lib/w4os/www/user/config/plugins/w4os.yaml`, `engine: bundled`, see the README of the plugin). It asks the address of the engine API, its own and never under the helpers (`https://grid.example.org/api`, or on the machine of the grid the one `opensim web GRID api` serves, on a port of the grid: the engine of the machine gives it, and setup proposes it), the address of the helpers of the grid for the blocks (`https://grid.example.org/helpers`), and the API key of the site, made on the machine of the grid with `opensim api-key create w4os-site`; it checks that the API answers, sets `engine: remote` and names the site after the grid. Options: `--api`, `--url`, `--key`, `--grid` (when the API serves several grids), `--title`, and `--no-mail` for a test site (the engine mails nothing, the confirmation links are shown on the page; `--mail` turns the mails back on).
- `web apache|caddy|nginx [--host <name>[,<name>...]] [--port <port>]` prints the configuration of the web server for the site; `--install` writes and enables it (Apache, Caddy). With `--prefix /opensim` (Caddy), the site is under that path, in blocks of their own whose addresses have the path (`grid.example.org/opensim`): Caddy prefers them to the block of the host, which they never change, so whatever runs at the root (a static page, WordPress) stays as it is; `--install` writes them in `/etc/caddy/sites/<host>.w4os.caddyfile` (the Caddyfile imports `sites/*`), checks them with the rest and reloads Caddy. Under a prefix, the helpers of the grid of this machine under it come first (`opensim web GRID snippet caddy --prefix`). The site runs in the PHP pool of the web server's user, never in the one of the engine API, which runs with the rights of the grid. Without a prefix, it routes nothing to the helpers of the grid: the site serves its own helpers when it is set so (the setting **Serve the helpers** of the w4os plugin, under the prefix of its helpers address); helpers installed apart are the web server's business, and their requests never reach the site.
- `status` tells what the site is connected to and whether the API answers.

The top bar has the menu of the site in the middle, and on the right the languages (oli-langswitcher), the menu of the visitor (sign in, or the avatar signed in) and the day and night switch. The languages are those of the OpenSim suite (`languages.supported` in `/var/lib/w4os/www/user/config/system.yaml`).

Then edit the pages in `/var/lib/w4os/www/user/pages` (Markdown, English and French), with the blocks of the helpers. Links between pages are written without the language (`[Create your avatar](/register)`): Grav adds it.

```markdown
[w4os block="grid-info" /]
[w4os block="grid-status" /]
[w4os block="search" /]
```

## Staying signed in

A visitor stays signed in as on a social network: until they sign out. "Remember me" is checked on the sign-in page and lasts a year; without it, the session lasts a day without a visit. A session back by "remember me" takes the avatar as the engine has it then: its level and its rights of now, and a banned, disabled or deleted avatar is signed out.

| Setting | Where (`user/config` of the site: `/var/lib/w4os/www/user/config` with the package) | Default |
| --- | --- | --- |
| How long "remember me" lasts, in seconds; `enabled: false` removes it | `plugins/login.yaml`, `rememberme.timeout` | `31536000` (a year) |
| How long a session lasts without a visit, in seconds | `system.yaml`, `session.timeout` and `session.options.gc_maxlifetime` | `86400` (a day) |
| Where the sessions are kept | `system.yaml`, `session.options.save_path` | `user/data/sessions` |
| The avatars kept as accounts of the site, which "remember me" needs | `plugins/w4os.yaml`, `save_accounts` | `true` |

The sessions are kept in a folder of the site, not the system's: Debian and Ubuntu clean the system's folder every half hour and take the sessions idle for 24 minutes, whatever the site sets. An upgrade does not change the settings of a site that exists: copy these lines from `/usr/share/w4os-site/site/user/config` into its own.

## Where things are

| What | Where |
| --- | --- |
| The site: Grav, its plugins and themes, its pages, settings, accounts, API key, sessions, caches and logs (a standard Grav site, the web server's user's) | `/var/lib/w4os/www`, the document root |
| The site the package ships, for a new site and its upgrades (never served) | `/usr/share/w4os-site/site` |
| What the package put in the site, file by file | `/var/lib/w4os/www/user/data/w4os-site/manifest` |
| Grav 1.7 and its Quark 2, for PHP older than 8.3 (never served) | `/usr/share/w4os-site/site-grav17` |

An upgrade of the package replaces Grav, a plugin or a theme of the site only where the site still has it as the package put it; one the site changed or updated (GPM, the admin) is left as it is, and the upgrade says so, as is a plugin the site removed. The pages, the settings and the accounts are never touched; neither is the site by the removal of the package, even purged.

Where PHP is older than 8.3 (Debian 12), Grav 2 cannot run: the site gets Grav 1.7 and the last Quark 2 made for it, and the same
plugins. Once PHP is 8.3 or newer (an upgrade to Debian 13), the next upgrade of the package, or `sudo dpkg-reconfigure w4os-site`,
gives it Grav 2 and its Quark 2, where it still has them as the package put them.

A site installed by a version before this one (Grav in `/usr/share/w4os-site/grav`, the content in `/var/lib/w4os-site`) moves to `/var/lib/w4os/www` at the upgrade, with its content, the plugins and themes added to it, and the root of the Apache configuration `w4os-site web` wrote; the folders of before are kept in `/var/lib/w4os-site.migrated`.

A site in `/var/lib/opensim/www` (the versions before w4os took its name) moves to `/var/lib/w4os/www` at the upgrade, `/var/lib/opensim/www` left as a link to it, so that the web server configurations that serve it from there keep working; the Apache configuration `w4os-site web` wrote serves it from its new folder.

## Grav admin (optional)

The site needs no admin: the avatars are managed on the site itself, by the managers of the grid (the w4os plugin, at `/w4os`). Grav's admin
(`admin2`, with the `api` plugin it needs) can be added for the pages and the settings:

```bash
cd /var/lib/w4os/www
sudo -u www-data php bin/gpm install admin2
sudo -u www-data php bin/plugin login new-user    # an account of the site, with the admin access
```

Then open `/admin`. It is the site's own: upgrades of the package leave it as it is.

## License

AGPL-3.0-or-later.

Third-party assets: the site ships Font Awesome Free 7.0.1 (`user/themes/w4os/css/fontawesome`, `css/webfonts`), icons under CC BY 4.0, fonts under SIL OFL 1.1, code under MIT, redistributed as released, with its `LICENSE.txt` and the attribution comments of its CSS.
