<?php
// A fake engine API for the tests: /api/info with the key osk_test; the avatars Ada Love (a resident) and God Test (a god, level
// 200) sign in with the password "secret"; /api/openapi.json the contract of the engine the site ships (W4OS_FAKE_OPENAPI)
// The grid info of a running grid (the bundled engine describes the grid from it): its helpers set on the site (economy, the
// next port), under /helpers
if (parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) === '/get_grid_info') {
    $site = 'http://127.0.0.1:'.((int) ($_SERVER['SERVER_PORT'] ?? 0) + 1);
    header('Content-Type: text/xml');
    echo '<gridinfo><platform>OpenSim</platform><gridname>Demo Grid</gridname><gridnick>demo</gridnick><login>http://127.0.0.1:'.(int) ($_SERVER['SERVER_PORT'] ?? 0).'/</login><economy>'.$site.'/helpers/</economy></gridinfo>';
    exit;
}
if (($_SERVER['HTTP_AUTHORIZATION'] ?? '') !== 'Bearer osk_test') {
    http_response_code(401);
    exit;
}
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$ada = ['type' => 'avatars', 'id' => 'a1', 'attributes' => [
    'uuid' => 'a1', 'name' => 'Ada Love', 'slug' => 'ada-love', 'email' => 'ada@example.org', 'level' => 0, 'status' => 'active',
]];
$god = ['type' => 'avatars', 'id' => 'g1', 'attributes' => [
    'uuid' => 'g1', 'name' => 'God Test', 'slug' => 'god-test', 'email' => 'god@example.org', 'level' => 200, 'status' => 'active',
]];
$answer = function (int $status, array $document) {
    http_response_code($status);
    header('Content-Type: '.($status < 400 ? 'application/vnd.api+json' : 'application/problem+json'));
    echo json_encode($document);
    exit;
};
if ($path === '/api/openapi.json' && is_file((string) getenv('W4OS_FAKE_OPENAPI'))) {
    header('Content-Type: application/json');
    readfile((string) getenv('W4OS_FAKE_OPENAPI'));
    exit;
}
if ($path === '/api/info') {
    $answer(200, ['data' => ['type' => 'info', 'id' => 'demo', 'attributes' => ['elements' => ['gridname' => 'Demo Grid', 'gridnick' => 'demo']]]]);
}
if ($path === '/api/sign-ins' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $sent = (array) (json_decode((string) file_get_contents('php://input'), true)['data']['attributes'] ?? []);
    if (($sent['name'] ?? '') === 'Ada Love' && ($sent['password'] ?? '') === 'secret') {
        $answer(200, ['data' => $ada]);
    }
    if (($sent['name'] ?? '') === 'God Test' && ($sent['password'] ?? '') === 'secret') {
        $answer(200, ['data' => $god]);
    }
    $answer(401, ['title' => 'Refused', 'status' => 401, 'detail' => 'Wrong name or password', 'code' => 'sign_in_refused']);
}
// An avatar by its UUID or its name, as the engine finds it
if (in_array(rawurldecode($path), ['/api/avatars/a1', '/api/avatars/Ada Love'], true)) {
    $answer(200, ['data' => $ada]);
}
if (in_array(rawurldecode($path), ['/api/avatars/g1', '/api/avatars/God Test'], true)) {
    $answer(200, ['data' => $god]);
}
// The rule of the avatar models of the grid, kept for the site of the test (in the temporary folder of the system)
if (preg_match('#^/api/health/([a-z0-9]+)$#', $path, $line) === 1) {
    // One line checked now
    $line[1] === 'l1' || $answer(404, ['status' => 404, 'title' => 'Not found']);
    $answer(200, ['data' => ['type' => 'health-checks', 'id' => 'l1', 'attributes' => ['label' => 'login', 'kind' => 'address', 'url' => 'http://127.0.0.1/', 'level' => 'ok', 'status' => '200', 'ms' => 2, 'checkedAt' => time()]]]);
}
if ($path === '/api/health') {
    // The last report an hour ago; checked now when asked (refresh)
    $file = sys_get_temp_dir().'/w4os-fake-health-'.(int) ($_SERVER['SERVER_PORT'] ?? 0);
    is_file($file) || file_put_contents($file, (string) (time() - 3600));
    ($_GET['refresh'] ?? '') === '1' && file_put_contents($file, (string) time());
    $answer(200, ['data' => ['type' => 'health', 'id' => 'demo', 'attributes' => ['level' => 'ok', 'checkedAt' => (int) file_get_contents($file), 'cached' => ($_GET['refresh'] ?? '') !== '1', 'groups' => [
        ['file' => 'get_grid_info', 'title' => '', 'rows' => [['id' => 'l1', 'label' => 'login', 'kind' => 'address', 'url' => 'http://127.0.0.1/', 'level' => 'ok', 'status' => '200', 'ms' => 3, 'checkedAt' => (int) file_get_contents($file)]]],
    ]]]]);
}
if ($path === '/api/addresses') {
    // Where the services of the grid are, each its use, its file, its section and key
    $answer(200, ['data' => ['type' => 'addresses', 'id' => 'demo', 'attributes' => ['services' => [
        ['key' => 'asset', 'url' => 'http://127.0.0.1:8003', 'source' => 'provider', 'usage' => 'robust-simulators', 'file' => 'OpenSim.ini', 'section' => 'AssetService', 'setting' => 'AssetServerURI', 'label' => 'service_asset', 'description' => 'service_asset_help'],
        ['key' => 'motd', 'url' => 'http://127.0.0.1/helpers/motd.php', 'source' => 'config', 'usage' => 'page', 'file' => 'Robust.HG.ini', 'section' => 'LoginService', 'setting' => 'MessageUrl', 'label' => 'setting_message_url', 'description' => 'setting_message_url_help'],
        ['key' => 'guide', 'url' => null, 'source' => null, 'usage' => 'page', 'file' => 'Robust.HG.ini', 'section' => 'LoginService', 'setting' => 'DestinationGuide', 'label' => 'setting_destination_guide', 'description' => 'setting_destination_guide_help'],
    ]]]]);
}
if ($path === '/api/regions/r1') {
    // A region of the grid, and its parcels
    $answer(200, ['data' => ['type' => 'regions', 'id' => 'r1', 'attributes' => [
        'uuid' => 'r1', 'name' => 'Test East', 'location' => '8015,8012', 'size' => '256x256', 'enabled' => true, 'online' => true, 'local' => true, 'hyperlink' => false,
    ]]]);
}
if ($path === '/api/parcels') {
    $region = (string) ($_GET['filter']['region'] ?? '');
    $parcels = $region !== 'r1' ? [] : [['type' => 'parcels', 'id' => 'p1', 'attributes' => [
        'uuid' => 'p1', 'name' => 'Plaza', 'region' => 'r1', 'regionName' => 'Test East', 'ownerName' => 'God Test', 'area' => 65536,
        'uri' => '127.0.0.1:8002/Test East/128/128/25', 'teleport' => 'hop://127.0.0.1:8002/Test%20East/128/128/25',
    ]]];
    $answer(200, ['data' => $parcels, 'meta' => ['total' => count($parcels), 'page' => 1, 'perPage' => 50]]);
}
if ($path === '/api/posts') {
    // The posts of every avatar of the grid, newest first
    $answer(200, ['data' => [
        ['type' => 'posts', 'id' => 'f2', 'attributes' => ['uuid' => 'f2', 'content' => 'Opening night at the Plaza', 'author' => 'g1', 'name' => 'God Test', 'created' => '2026-11-19T10:00:00Z']],
        ['type' => 'posts', 'id' => 'f1', 'attributes' => ['uuid' => 'f1', 'content' => 'Hello from Ada', 'author' => 'a1', 'name' => 'Ada Love', 'created' => '2026-11-18T09:00:00Z']],
    ], 'meta' => ['total' => 2, 'page' => 1, 'perPage' => 50]]);
}
if ($path === '/api/avatars' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    // A new avatar: what was sent kept for the test, the avatar made
    $sent = (array) (json_decode((string) file_get_contents('php://input'), true)['data']['attributes'] ?? []);
    file_put_contents(sys_get_temp_dir().'/w4os-fake-new-avatar-'.(int) ($_SERVER['SERVER_PORT'] ?? 0).'.json', json_encode($sent));
    $answer(201, ['data' => ['type' => 'avatars', 'id' => 'n1', 'attributes' => [
        'uuid' => 'n1', 'name' => trim(($sent['firstName'] ?? '').' '.($sent['lastName'] ?? '')), 'level' => 0, 'status' => 'active',
    ]]]);
}
if ($path === '/api/avatars') {
    // The avatars of the grid, with the number of avatars each value of a filter gives (meta.counts)
    $answer(200, ['data' => [$ada, $god], 'meta' => ['total' => 2, 'page' => 1, 'perPage' => 50, 'counts' => [
        'online' => ['online' => 1, 'offline' => 1], 'type' => ['user' => 2, 'model' => 0, 'service' => 0], 'active' => ['yes' => 2, 'no' => 0],
        'status' => ['active' => 2, 'disabled' => 0, 'pending' => 0, 'banned' => 0],
    ]]]);
}
if ($path === '/api/avatar-models') {
    // The models the rule of the grid picks (the settings below), or the one its filters ask
    $file = sys_get_temp_dir().'/w4os-fake-models-'.(int) ($_SERVER['SERVER_PORT'] ?? 0).'.json';
    $rule = (array) ($_GET['filter'] ?? []) + (is_file($file) ? (array) json_decode((string) file_get_contents($file), true) : ['match' => 'any', 'pattern' => 'Default', 'list' => []]);
    $list = is_array($rule['list'] ?? null) ? $rule['list'] : array_filter(explode(',', (string) ($rule['list'] ?? '')));
    $avatars = ['m1' => 'Default Ruth', 'm2' => 'Default Roth', 'a1' => 'Ada Love', 'g1' => 'God Test'];
    $picked = array_filter($avatars, function ($name, $uuid) use ($rule, $list) {
        [$first, $last] = explode(' ', $name);
        return match ($rule['match'] ?? 'any') {
            'uuid' => in_array($uuid, $list, true),
            'first' => $first === ($rule['pattern'] ?? ''),
            'last' => $last === ($rule['pattern'] ?? ''),
            default => in_array($rule['pattern'] ?? '', [$first, $last], true),
        };
    }, ARRAY_FILTER_USE_BOTH);
    $answer(200, ['data' => array_values(array_map(fn ($uuid) => ['type' => 'avatar-models', 'id' => $uuid, 'attributes' => [
        'uuid' => $uuid, 'name' => $avatars[$uuid], 'label' => $avatars[$uuid], 'picture' => '00000000-0000-0000-0000-000000000000',
    ]], array_keys($picked)))]);
}
if ($path === '/api/settings/models') {
    $file = sys_get_temp_dir().'/w4os-fake-models-'.(int) ($_SERVER['SERVER_PORT'] ?? 0).'.json';
    $rule = is_file($file) ? (array) json_decode((string) file_get_contents($file), true) : ['match' => 'any', 'pattern' => 'Default', 'list' => []];
    if ($_SERVER['REQUEST_METHOD'] === 'PATCH') {
        $rule = array_merge($rule, (array) (json_decode((string) file_get_contents('php://input'), true)['data']['attributes'] ?? []));
        file_put_contents($file, json_encode($rule));
    }
    $answer(200, ['data' => ['type' => 'settings', 'id' => 'models', 'attributes' => $rule]]);
}
if (preg_match('#^/api/settings/(economy|search|guide|offline|assets)$#', $path, $m) === 1) {
    // The settings of a service: the economy of the grid set by its options (its module), the rest changed here
    $file = sys_get_temp_dir().'/w4os-fake-'.$m[1].'-'.(int) ($_SERVER['SERVER_PORT'] ?? 0).'.json';
    $values = is_file($file) ? (array) json_decode((string) file_get_contents($file), true)
        : ['economyUrl' => '', 'economyModule' => 'BetaGridLikeMoneyModule', 'currencyRate' => null];
    if ($_SERVER['REQUEST_METHOD'] === 'PATCH') {
        $values = array_merge($values, (array) (json_decode((string) file_get_contents('php://input'), true)['data']['attributes'] ?? []));
        file_put_contents($file, json_encode($values));
    }
    $answer(200, ['data' => ['type' => 'settings', 'id' => $m[1], 'attributes' => $values]]);
}
http_response_code(404);
