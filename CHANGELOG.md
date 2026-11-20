# Changelog

## Unreleased

- new (packaging): the copyright file of the package
- update (pages): the login URI of the default pages as [login-uri], their title as [grid-name], their slogan as [site-slogan], without a closing slash
- fix (tree): the folder of the site made 755 whatever the umask of the machine
- fix (sessions): several browsers signed in at once, and several pages a browser opens at once, no longer taken for a stolen "remember me" cookie (w4os plugin); a stolen one lands on the sign-in page with a message, not an error page
- update (sessions): signed in until signing out: "remember me" checked and lasting a year, a session a day without a visit, the sessions in a folder of the site (`user/data/sessions`, the package's `/var/lib/w4os-site/sessions`) out of the reach of the system's cleaning, which took them after 24 minutes; the avatars kept as accounts so "remember me" finds them
- new: Grav 2.2 with the w4os plugin, the light theme w4os (a child of Quark2), the default pages (home, help, English and French)
- new: `w4os-site setup`, `status` and `web` (Apache, Caddy, nginx)
- new: Debian package, the content of the site in /var/lib/w4os-site, caches in /var/cache/w4os-site
