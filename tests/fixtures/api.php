<?php
// A fake engine API for the tests of the installer: /api/info with the key osk_test
if (($_SERVER['HTTP_AUTHORIZATION'] ?? '') !== 'Bearer osk_test') {
    http_response_code(401);
    exit;
}
if (parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) === '/api/info') {
    header('Content-Type: application/vnd.api+json');
    echo '{"data":{"type":"info","id":"demo","attributes":{"elements":{"gridname":"Demo Grid","gridnick":"demo"}}}}';
    exit;
}
http_response_code(404);
