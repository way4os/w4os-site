# w4os site

The light website of an [OpenSimulator](http://opensimulator.org) grid, installable by anyone on any server: avatars register with a model and confirm their email, sign in, manage their account and their password; the managers of the grid manage the avatars; Markdown pages show the blocks of the helpers (grid info, grid status, search, profile...). It talks to the OpenSim engine API of the grid, which does everything.

It is [Grav](https://getgrav.org) with the [w4os plugin](https://github.com/magicoli/grav-plugin-w4os), a light theme and default pages, in one Debian package. For the full application, see w4os-app (later); to add the same pages to an existing Grav or WordPress site, use the w4os plugin of that site.

## Requirements

- A Debian or Ubuntu server with PHP 8.3 or newer and a web server (Apache, Caddy or nginx; PHP-FPM recommended).
- An OpenSimulator grid, on this machine or another one: with its OpenSim helpers version 3 and an API key for the site, or with its Robust database reachable from the site (the w4os plugin carries the engine and the helpers: no OpenSim package is needed on the server of the site).

## Install

### The zip, anywhere

The site as a zip (`w4os-site-<version>.zip`, on the release): Grav, its plugins, the theme, Font Awesome and the defaults of a new site, nothing to build or download.

1. Unzip it where the web server serves it (`unzip w4os-site-<version>.zip -d /var/www/`), and give the web server the folders it writes: `user/config`, `user/pages`, `user/accounts`, `user/data`, `assets`, `images`, `cache`, `tmp`, `logs` and `backup` of `w4os-site/`.
2. Point the web server at `w4os-site/` (the configurations Grav gives are in `webserver-configs/`), with PHP 8.3 or later and its extensions curl, gd, mbstring, xml, zip and intl (pdo_mysql too, for the engine bundled with the plugin).
3. Connect it to the grid in `user/config/plugins/w4os.yaml`: `engine: remote`, `api_url` (the engine API, `https://grid.example.org/api`), `url` (the helpers, for the blocks) and `grid`; the API key of the site (`opensim api-key create w4os-site`, on the machine of the grid) in `user/data/w4os/api.json`, `{"api_key": "osk_..."}`, readable by the web server only. With Grav's admin, the settings page of the plugin does both.

To try it on a computer: `php -S localhost:8000 system/router.php` in `w4os-site/`.

### Debian, with apt

On Debian and Ubuntu, the package installs the same site and keeps it up to date:

```bash
sudo apt install w4os-site            # or: sudo apt install ./w4os-site_<version>_all.deb
sudo w4os-site setup                  # asks the address of the helpers and the API key
sudo w4os-site web apache --host grid.example.org --install
```

- `setup` connects the site to the API of the grid (the bundled engine is set in `/var/lib/w4os-site/config/plugins/w4os.yaml`, `engine: bundled`, see the README of the plugin). It asks the address of the engine API, its own and never under the helpers (`https://grid.example.org/api`, or `http://127.0.0.1:8780/api` on the machine of the grid, served by `opensim web GRID api`), the address of the helpers of the grid for the blocks (`https://grid.example.org/helpers`), and the API key of the site, made on the machine of the grid with `opensim api-key create w4os-site`; it checks that the API answers, sets `engine: remote` and names the site after the grid. Options: `--api`, `--url`, `--key`, `--grid` (when the API serves several grids), `--title`, and `--no-mail` for a test site (the engine mails nothing, the confirmation links are shown on the page; `--mail` turns the mails back on).
- `web apache|caddy|nginx [--host <name>] [--port <port>]` prints the configuration of the web server for the site; `--install` writes and enables it (Apache). On a machine of the grid with the helpers package, the Apache one serves the helpers of the grid (`/helpers`) from their package, as `opensim web GRID snippet apache` prints it: the site is then a client of the engine API (`setup --api`) and leaves the helpers to their package.
- `status` tells what the site is connected to and whether the API answers.

The top bar has the menu of the site in the middle, and on the right the languages (oli-langswitcher), the menu of the visitor (sign in, or the avatar signed in) and the day and night switch. The languages are those of the OpenSim suite (`languages.supported` in `/var/lib/w4os-site/config/system.yaml`).

Then edit the pages in `/var/lib/w4os-site/pages` (Markdown, English and French), with the blocks of the helpers. Links between pages are written without the language (`[Create your avatar](/register)`): Grav adds it.

```markdown
[w4os block="grid-info" /]
[w4os block="grid-status" /]
[w4os block="search" /]
```

## Where things are

| What | Where |
| --- | --- |
| Grav, its plugins, the theme (replaced by upgrades) | `/usr/share/w4os-site/grav`, the document root |
| The pages, the settings, the accounts, the API key | `/var/lib/w4os-site` (never touched by upgrades nor removal) |
| Caches | `/var/cache/w4os-site` |
| Logs | `/var/log/w4os-site` |

## Grav admin (optional)

The site needs no admin: the avatars are managed on the site itself, by the managers of the grid (the w4os plugin). Grav's admin
(`admin2`, with the `api` plugin it needs) can be added for the pages and the settings:

```bash
cd /usr/share/w4os-site/grav
sudo php bin/gpm install admin2
sudo chown -R www-data:www-data /var/lib/w4os-site /var/cache/w4os-site /var/log/w4os-site
sudo -u www-data php bin/plugin login new-user    # an account of the site, with the admin access
```

Then open `/admin`. It is kept by the upgrades of the package (its folders are not the package's) and saves the settings in
`/var/lib/w4os-site/config`. To remove it, delete its folders: `sudo rm -r user/plugins/admin2 user/plugins/api`. Never
`bin/gpm uninstall`: it also removes the plugins of the package that admin2 shares (login, email, shortcode-core); `sudo apt
install --reinstall w4os-site` puts them back.

## License

AGPL-3.0-or-later.

Third-party assets: the site ships Font Awesome Free 7.0.1 (`user/themes/w4os/css/fontawesome`, `css/webfonts`), icons under CC BY 4.0, fonts under SIL OFL 1.1, code under MIT, redistributed as released, with its `LICENSE.txt` and the attribution comments of its CSS.
