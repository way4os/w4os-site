# w4os site

The light website of an [OpenSimulator](http://opensimulator.org) grid, installable by anyone on any server: avatars register with a model and confirm their email, sign in, manage their account and their password; the managers of the grid manage the avatars; Markdown pages show the blocks of the helpers (grid info, grid status, search, profile...). It talks to the OpenSim engine API of the grid, which does everything.

It is [Grav](https://getgrav.org) with the [w4os plugin](https://github.com/magicoli/grav-plugin-w4os), a light theme and default pages, in one Debian package. For the full application, see w4os-app (later); to add the same pages to an existing Grav or WordPress site, use the w4os plugin of that site.

## Requirements

- A Debian or Ubuntu server with PHP 8.3 or newer and a web server (Apache, Caddy or nginx; PHP-FPM recommended).
- An OpenSimulator grid with the OpenSim helpers version 3 (`opensim-helpers`), on this machine or another one, and an API key for the site.

## Install

```bash
sudo apt install w4os-site            # or: sudo apt install ./w4os-site_<version>_all.deb
sudo w4os-site setup                  # asks the address of the helpers and the API key
sudo w4os-site web apache --host grid.example.org --install
```

- `setup` asks the address of the helpers of the grid (`https://grid.example.org/helpers`) and the API key of the site, made on the machine of the grid with `opensim api-key create w4os-site`; it checks that the API answers and names the site after the grid. Options: `--url`, `--key`, `--grid` (when the API serves several grids), `--title`.
- `web apache|caddy|nginx [--host <name>] [--port <port>]` prints the configuration of the web server for the site; `--install` writes and enables it (Apache).
- `status` tells what the site is connected to and whether the API answers.

Then edit the pages in `/var/lib/w4os-site/pages` (Markdown, English and French), with the blocks of the helpers:

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
