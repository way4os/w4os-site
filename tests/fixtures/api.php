<?php
// A fake engine API for the tests: /api/info with the key osk_test; the avatars Ada Love (a resident) and God Test (a god, level
// 200) sign in with the password "secret"
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
if ($path === '/api/avatars/a1') {
    $answer(200, ['data' => $ada]);
}
if ($path === '/api/avatars/g1') {
    $answer(200, ['data' => $god]);
}
http_response_code(404);
