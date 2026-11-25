<?php

namespace Grav\Theme;

/** The light theme of the w4os site: Quark2, with the colors, the logo and the footer of the site. */
class W4os extends Quark2
{
    /** The logo the theme gave the sites before (OpenSimulator's): a site that kept it has no logo of its own, its name shows. */
    public const OLD_DEFAULT_LOGO = 'user/themes/w4os/images/logo/opensimulator-logo.png';

    public function onThemeInitialized()
    {
        parent::onThemeInitialized();
        foreach (['custom_logo', 'custom_logo_mobile'] as $field) {
            $files = (array) $this->config->get("theme.$field", []);
            if ($files !== [] && array_keys($files) === [self::OLD_DEFAULT_LOGO]) {
                $this->config->set("theme.$field", []);
                $this->config->set('themes.'.$this->name.".$field", []);
            }
        }
    }
}
