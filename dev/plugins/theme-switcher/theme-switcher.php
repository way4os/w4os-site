<?php

namespace Grav\Plugin;

use Grav\Common\Plugin;

/**
 * Development only: the theme a visitor asks with ?theme=<name>, kept in a cookie for the next pages (?theme= alone goes back to
 * the theme of the site), picked in a small menu at the corner of every page. Set before Grav loads its theme
 * (onPluginsInitialized comes before the themes), as the core reads it (system.pages.theme); the menu added to the page once it is
 * made, in its own styles, so that no theme is touched. Never in the package of the site: dev/deploy.sh puts it on a server of
 * development.
 */
class ThemeSwitcherPlugin extends Plugin
{
    public const COOKIE = 'grav-dev-theme';

    /** @var list<string> */
    private array $themes = [];

    private string $site = '';

    public static function getSubscribedEvents(): array
    {
        return ['onPluginsInitialized' => ['onPluginsInitialized', 1000]];
    }

    public function onPluginsInitialized(): void
    {
        if ($this->isAdmin()) {
            return;
        }
        $this->themes = array_map('basename', glob($this->grav['locator']->findResource('themes://').'/*', GLOB_ONLYDIR) ?: []);
        $this->site = (string) $this->config->get('system.pages.theme');
        $theme = self::chosen(isset($_GET['theme']) ? (string) $_GET['theme'] : null, $_COOKIE[self::COOKIE] ?? null, $this->themes);
        if (isset($_GET['theme'])) {
            setcookie(self::COOKIE, (string) $theme, ['expires' => $theme ? time() + 30 * 86400 : 1, 'path' => '/', 'samesite' => 'Lax']);
        }
        $theme && $this->config->set('system.pages.theme', $theme);
        // Not in a viewer's panel, whose page is the site's alone
        str_contains((string) ($_SERVER['HTTP_USER_AGENT'] ?? ''), 'SecondLife') || $this->enable(['onOutputGenerated' => ['onOutputGenerated', -1000]]);
    }

    /** The menu of the themes at the end of the page. */
    public function onOutputGenerated(): void
    {
        $this->grav->output = self::withPicker((string) $this->grav->output, self::picker($this->themes, (string) $this->config->get('system.pages.theme'), $this->site));
    }

    /**
     * The menu of the themes: the site's own first (?theme= alone), then the others, the one shown selected; fixed at a corner of
     * the page in its own styles, whatever the theme.
     *
     * @param list<string> $themes
     */
    public static function picker(array $themes, string $current, string $site): string
    {
        $option = static fn(string $value, string $label, bool $selected): string => '<option value="' . htmlspecialchars($value) . '"' . ($selected ? ' selected' : '') . '>' . htmlspecialchars($label) . '</option>';
        $options = $option('', $site, $current === $site);
        foreach ($themes as $theme) {
            $theme === $site || $options .= $option($theme, $theme, $theme === $current);
        }

        return '<nav aria-label="Theme" style="position:fixed;right:.5rem;bottom:.5rem;z-index:2147483647;margin:0;padding:.25rem .4rem;'
            . 'font:12px/1.2 system-ui,sans-serif;color:#111;background:#fffe;border:1px solid #999;border-radius:.4rem;box-shadow:0 1px 4px #0003">'
            . '<label style="all:revert;font:inherit;color:inherit">Theme <select style="all:revert;font:inherit" '
            . 'onchange="var u=new URL(location.href);u.searchParams.set(\'theme\',this.value);location.href=u">' . $options . '</select></label></nav>';
    }

    /** A page with the menu before its end; anything else (a feed, JSON) as it is. */
    public static function withPicker(string $html, string $picker): string
    {
        $end = strripos($html, '</body>');

        return $end === false ? $html : substr($html, 0, $end) . $picker . substr($html, $end);
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
