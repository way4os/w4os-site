<?php
// A browser for the tests, its cookies kept as browsers keep them (RFC 6265): one per name, domain (or host only) and path; a cookie
// of other attributes never replaces another one of the same name; the ones of the longest path sent first, then the oldest.
//
//   php browser.php JAR get|post URL [--resolve HOST:PORT:ADDRESS] [--header 'Name: value']... [--follow] [field=value...]
//       the page (its status, then its address, on stderr), the cookies kept; --follow goes where it redirects (a GET)
//   php browser.php JAR seed URL NAME VALUE DOMAIN PATH   a cookie kept before (DOMAIN '' for the host only), older than the others
//   php browser.php JAR count NAME                        how many cookies of that name it keeps
//   php browser.php JAR sent URL NAME                     how many of them it sends to that address
//   php browser.php JAR paths NAME                        the paths of the cookies of that name it keeps
//   php browser.php JAR drop NAME                         the cookies of that name forgotten
[, $file, $command] = $argv + [null, null, null];
$jar = is_file($file) ? (array) json_decode((string) file_get_contents($file), true) : [];
$save = function () use (&$jar, $file): void {
    file_put_contents($file, json_encode(array_values($jar)));
};

$matches = function (array $cookie, string $url): bool {
    $host = strtolower((string) parse_url($url, PHP_URL_HOST));
    $path = (string) (parse_url($url, PHP_URL_PATH) ?: '/');
    $domain = $cookie['domain'];
    $hostOk = $cookie['hostOnly'] ? $host === $domain : ($host === $domain || str_ends_with($host, '.'.$domain));
    $p = $cookie['path'];
    $pathOk = $path === $p || (str_starts_with($path, $p) && (str_ends_with($p, '/') || $path[strlen($p)] === '/'));

    return $hostOk && $pathOk && $cookie['expires'] > time();
};
$sent = function (string $url) use (&$jar, $matches): array {
    $cookies = array_values(array_filter($jar, fn ($c) => $matches($c, $url)));
    usort($cookies, fn ($a, $b) => [strlen($b['path']), $a['created']] <=> [strlen($a['path']), $b['created']]);

    return $cookies;
};
$keep = function (string $header, string $url) use (&$jar): void {
    $parts = array_map('trim', explode(';', $header));
    [$name, $value] = array_map('trim', explode('=', array_shift($parts), 2)) + [1 => ''];
    $host = strtolower((string) parse_url($url, PHP_URL_HOST));
    $path = (string) (parse_url($url, PHP_URL_PATH) ?: '/');
    $cookie = ['name' => $name, 'value' => $value, 'domain' => $host, 'hostOnly' => true, 'expires' => PHP_INT_MAX, 'created' => microtime(true),
        'path' => substr($path, 0, (int) strrpos($path, '/')) ?: '/'];
    foreach ($parts as $part) {
        [$key, $v] = array_map('trim', explode('=', $part, 2)) + [1 => ''];
        match (strtolower($key)) {
            'domain' => $v === '' ? null : [$cookie['domain'] = strtolower(ltrim($v, '.')), $cookie['hostOnly'] = false],
            'path' => $cookie['path'] = $v === '' ? '/' : $v,
            'max-age' => $cookie['expires'] = (int) $v <= 0 ? 0 : time() + (int) $v,
            'expires' => isset($seen) ? null : $cookie['expires'] = min($cookie['expires'], strtotime($v) ?: PHP_INT_MAX),
            default => null,
        };
        strtolower($key) === 'max-age' && $seen = true;
    }
    $same = fn ($c) => $c['name'] === $cookie['name'] && $c['domain'] === $cookie['domain'] && $c['hostOnly'] === $cookie['hostOnly'] && $c['path'] === $cookie['path'];
    foreach ($jar as $i => $c) {
        if ($same($c)) {
            $cookie['created'] = $c['created'];
            unset($jar[$i]);
        }
    }
    $cookie['expires'] > time() && $jar[] = $cookie;
};

switch ($command) {
    case 'seed':
        [, , , $url, $name, $value, $domain, $path] = $argv;
        $jar[] = ['name' => $name, 'value' => $value, 'domain' => $domain === '' ? strtolower((string) parse_url($url, PHP_URL_HOST)) : $domain,
            'hostOnly' => $domain === '', 'path' => $path, 'expires' => PHP_INT_MAX, 'created' => 0];
        $save();
        break;
    case 'count':
        echo count(array_filter($jar, fn ($c) => $c['name'] === $argv[3]))."\n";
        break;
    case 'drop':
        $jar = array_filter($jar, fn ($c) => $c['name'] !== $argv[3]);
        $save();
        break;
    case 'paths':
        echo implode(' ', array_column(array_filter($jar, fn ($c) => $c['name'] === $argv[3]), 'path'))."\n";
        break;
    case 'sent':
        echo count(array_filter($sent($argv[3]), fn ($c) => $c['name'] === $argv[4]))."\n";
        break;
    case 'get':
    case 'post':
        $url = $argv[3];
        $rest = array_slice($argv, 4);
        $resolve = $extra = [];
        $follow = false;
        while (in_array($rest[0] ?? '', ['--resolve', '--header', '--follow'], true)) {
            $option = array_shift($rest);
            match ($option) {
                '--resolve' => $resolve[] = array_shift($rest),
                '--header' => $extra[] = array_shift($rest),
                '--follow' => $follow = true,
            };
        }
        $fields = [];
        foreach ($rest as $pair) {
            [$k, $v] = explode('=', $pair, 2) + [1 => ''];
            $fields[$k] = $v;
        }
        for ($hops = 0; ; $hops++) {
            $cookies = implode('; ', array_map(fn ($c) => $c['name'].'='.$c['value'], $sent($url)));
            $headers = [];
            $location = null;
            $curl = curl_init($url);
            curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_RESOLVE => $resolve,
                CURLOPT_HTTPHEADER => array_merge($extra, $cookies === '' ? [] : ['Cookie: '.$cookies]),
                CURLOPT_HEADERFUNCTION => function ($curl, $line) use (&$headers, &$location) {
                    stripos($line, 'set-cookie:') === 0 && $headers[] = trim(substr($line, 11));
                    stripos($line, 'location:') === 0 && $location = trim(substr($line, 9));

                    return strlen($line);
                }] + ($command === 'post' && $hops === 0 ? [CURLOPT_POST => true, CURLOPT_POSTFIELDS => http_build_query($fields)] : []));
            $body = (string) curl_exec($curl);
            foreach ($headers as $header) {
                $keep($header, $url);
            }
            $status = curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
            if (! $follow || $location === null || $hops >= 5) {
                break;
            }
            $url = str_contains($location, '://') ? $location : preg_replace('~^(\w+://[^/]+).*$~', '$1', $url).$location;
        }
        $save();
        fwrite(STDERR, "$status\n$url\n");
        echo $body;
        break;
}
