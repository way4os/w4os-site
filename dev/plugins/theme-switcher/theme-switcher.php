<?php

namespace Grav\Plugin;

use Grav\Common\Plugin;

/**
 * Development only: the theme a visitor asks with ?theme=<name>, kept in a cookie for the next pages (?theme= alone goes back to
 * the theme of the site). Set before Grav loads its theme (onPluginsInitialized comes before the themes), as the core reads it
 * (system.pages.theme). Never in the package of the site: dev/deploy.sh puts it on a server of development.
 */
class ThemeSwitcherPlugin extends Plugin
{
    public const COOKIE = 'grav-dev-theme';

    public static function getSubscribedEvents(): array
    {
        return ['onPluginsInitialized' => ['onPluginsInitialized', 1000]];
    }

    public function onPluginsInitialized(): void
    {
        if ($this->isAdmin()) {
            return;
        }
        $themes = array_map('basename', glob($this->grav['locator']->findResource('themes://').'/*', GLOB_ONLYDIR) ?: []);
        $theme = self::chosen(isset($_GET['theme']) ? (string) $_GET['theme'] : null, $_COOKIE[self::COOKIE] ?? null, $themes);
        if (isset($_GET['theme'])) {
            setcookie(self::COOKIE, (string) $theme, ['expires' => $theme ? time() + 30 * 86400 : 1, 'path' => '/', 'samesite' => 'Lax']);
        }
        $theme && $this->config->set('system.pages.theme', $theme);
    }

    /**
     * The theme to show: the one asked, else the one kept, if it is one of the themes there are; '' when the visitor asks the
     * theme of the site back, null for none.
     *
     * @param list<string> $themes
     */
    public static function chosen(?string $asked, ?string $kept, array $themes): ?string
    {
        if ($asked === '') {
            return '';
        }
        $theme = $asked ?? $kept;

        return $theme !== null && in_array($theme, $themes, true) ? $theme : null;
    }
}
