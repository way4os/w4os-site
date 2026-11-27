<?php
// Fake helpers of a grid for the tests, a server of their own at 127.0.0.1:PORT (php helpers.php PORT), each request in a
// process of its own, so that every block asked at once is answered at once: /helpers/blocks/{name} answers its name and the
// client asked, after the delay (ms) in the file "delay" of the folder W4OS_HELPERS (none: at once); each answer logged in its
// file "log" (its name, client and level, one a line)
$dir = (string) getenv('W4OS_HELPERS');
$server = stream_socket_server('tcp://127.0.0.1:'.(int) ($argv[1] ?? 0), $code, $error) ?: exit("helpers.php: $error\n");
pcntl_signal(SIGCHLD, SIG_IGN);
while (true) {
    $client = @stream_socket_accept($server, -1);
    if ($client === false || pcntl_fork() !== 0) {
        is_resource($client) && fclose($client);

        continue;
    }
    $line = (string) fgets($client);
    while (($header = fgets($client)) !== false && trim($header) !== '') {
    }
    $target = explode(' ', $line)[1] ?? '/';
    parse_str((string) parse_url($target, PHP_URL_QUERY), $query);
    $name = basename((string) parse_url($target, PHP_URL_PATH));
    $delay = is_file("$dir/delay") ? (int) trim((string) file_get_contents("$dir/delay")) : 0;
    $delay > 0 && usleep($delay * 1000);
    file_put_contents("$dir/log", implode(' ', array_filter([$name, $query['client'] ?? '', $query['level'] ?? ''], 'strlen'))."\n", FILE_APPEND | LOCK_EX);
    $body = '<div class="fake-block fake-'.htmlspecialchars($name).'">'.htmlspecialchars($name.' '.($query['client'] ?? '')).'</div>';
    @fwrite($client, "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: ".strlen($body)."\r\nConnection: close\r\n\r\n$body");
    fclose($client);
    exit(0);
}
