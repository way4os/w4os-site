# w4os site

The light website of an [OpenSimulator](http://opensimulator.org) grid, installable by anyone on any server: avatars register with a model and confirm their email, sign in, manage their account and their password; the managers of the grid manage the avatars; Markdown pages show the blocks of the helpers (grid info, grid status, search, profile...). It talks to the OpenSim engine API of the grid, which does everything.

It is [Grav](https://getgrav.org) with the [w4os plugin](https://github.com/magicoli/grav-plugin-w4os), a light theme and default pages, in one Debian package. For the full application, see w4os-app (later); to add the same pages to an existing Grav or WordPress site, use the w4os plugin of that site.

## Requirements

- A Debian or Ubuntu server with PHP 8.3 or newer and a web server (Apache, Caddy or nginx; PHP-FPM recommended).
- An OpenSimulator grid, on this machine or another one: with its OpenSim helpers version 3 and an API key for the site, or with its Robust database reachable from the site (the w4os plugin carries the engine and the helpers: no OpenSim package is needed on the server of the site).

## Install

```bash
sudo apt install w4os-site            # or: sudo apt install ./w4os-site_<version>_all.deb
sudo w4os-site setup                  # asks the address of the helpers and the API key
sudo w4os-site web apache --host grid.example.org --install
```

- `setup` connects the site to the API of the grid (the bundled engine is set in `/var/lib/w4os-site/config/plugins/w4os.yaml`, `engine: bundled`, see the README of the plugin). It asks the address of the helpers of the grid (`https://grid.example.org/helpers`) and the API key of the site, made on the machine of the grid with `opensim api-key create w4os-site`; it checks that the API answers and names the site after the grid. Options: `--url`, `--key`, `--grid` (when the API serves several grids), `--title`, and `--no-mail` for a test site (the engine mails nothing, the confirmation links are shown on the page; `--mail` turns the mails back on).
- `web apache|caddy|nginx [--host <name>] [--port <port>]` prints the configuration of the web server for the site; `--install` writes and enables it (Apache).
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

## License

AGPL-3.0-or-later.
