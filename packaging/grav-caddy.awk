# Grav's Caddyfile (webserver-configs/Caddyfile, made for a site alone) as a snippet a site block imports with its arguments:
#     import /usr/share/w4os-site/web/grav.caddy ROOT PHP SCRIPT_NAME
# ROOT the folder of the site, PHP the upstream of PHP-FPM (unix//run/php/php-fpm.sock), SCRIPT_NAME the address of its index.php
# (/index.php, /opensim/index.php under a prefix). Its rules as they are, without its comments, its address and its compression.
BEGIN { print "# Grav's rules for Caddy (webserver-configs/Caddyfile): import this file ROOT PHP SCRIPT_NAME" }
!started { started = ($0 == "localhost"); next }
$0 == "encode gzip" { next }
/^[[:space:]]*#/ { next }
/^[[:space:]]*$/ { blank = 1; next }
blank && printed { print "" }
{ blank = 0; printed = 1 }
$0 == "root * ." { print "root * {args[0]}"; next }
/^[[:space:]]*php_fastcgi / {
    indent = $0
    sub(/php_fastcgi.*/, "", indent)
    print indent "php_fastcgi {args[1]} {"
    print indent "\tenv SCRIPT_NAME {args[2]}"
    print indent "}"
    next
}
{ print }
