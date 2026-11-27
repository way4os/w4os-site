# Changelog

## Unreleased

- fix (web): an Apache started by its reload never keeps the terminal
- new (web): --modules names the modules of Apache the site enables; --remove disables the ones it enabled itself
- fix (web): the site served by its own pool of the suite (w4os-site, as the web user) once it is installed
- fix (web): beside Apache, the site takes a PHP-FPM socket only when Apache's account reaches it, else mod_php serves it
- fix (web): the helpers keep the pool of their own the engine gives them; the site never takes it, nor the API's
- change (web): web apache --prefix on its host alone: one IncludeOptional line in each site serving it, a copy before; --vhosts, --remove
- new (web): web apache --prefix: the site under a path for the sites of this Apache, in conf-available/w4os-site.conf
- fix (web): the snippet of Grav read by Caddy 2.6 (Debian 13, {args.N}); helpers all outside the prefix served; reload without systemd
- fix (setup): a kept key the engine refuses is replaced by a new one; setup --help, web --help give their own usage
- fix (web): one PHP socket for the site and the helpers; the helpers outside the prefix, one block a folder of the root
- change (web): the Caddy file of a site in a few lines, Grav's rules in a snippet the package ships (web/grav.caddy), imported
- new (web): web caddy --prefix also routes the helpers' addresses outside the prefix, each exactly, in a block of their own
- fix (web): --install follows the folder the Caddyfile imports (absolute too); a host given with its scheme makes no odd file name
- fix (web): under a prefix, the helpers of a command line too old for it (the paths of the root) are left out, with what to upgrade
- new (web): web caddy --prefix /opensim: the site under that path, in blocks of their own beside the one of the host, which they never change; --install for Caddy
- fix (web): the site runs in the PHP pool of the web user, never in the one of the engine API (w4os-api), taken by its name before
- fix (home): its welcome says the title of the site ([site-title]), not the ASCII name of the grid
- fix (setup): the title the site has is kept, the name of its grid (ASCII in its grid info) only proposed for a new site
- fix (packaging): the releases go to charm (stable, unstable), the builds between to charm-tests, as the other packages of the family
- new: `w4os-site --version`
- change (packaging): php-imagick is required, it decodes the web assets of the grid (JPEG 2000)
- new (packaging): the copyright file of the package
- update (pages): the login URI of the default pages as [login-uri], their title as [grid-name], their slogan as [site-slogan], without a closing slash
- fix (tree): the folder of the site made 755 whatever the umask of the machine
- fix (sessions): several browsers signed in at once, and several pages a browser opens at once, no longer taken for a stolen "remember me" cookie (w4os plugin); a stolen one lands on the sign-in page with a message, not an error page
- update (sessions): signed in until signing out: "remember me" checked and lasting a year, a session a day without a visit, the sessions in a folder of the site (`user/data/sessions`, the package's `/var/lib/w4os-site/sessions`) out of the reach of the system's cleaning, which took them after 24 minutes; the avatars kept as accounts so "remember me" finds them
- new: Grav 2.2 with the w4os plugin, the light theme w4os (a child of Quark2), the default pages (home, help, English and French)
- new: `w4os-site setup`, `status` and `web` (Apache, Caddy, nginx)
- new: Debian package, the content of the site in /var/lib/w4os-site, caches in /var/cache/w4os-site
