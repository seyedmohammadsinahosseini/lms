<?php
declare(strict_types=1);

if (PHP_SAPI !== 'cli') {
    fwrite(STDERR, "CLI only.\n");
    exit(1);
}
$root = dirname(__DIR__);
$helpers = is_file($root . '/backend/helpers.php')
    ? $root . '/backend/helpers.php'
    : $root . '/www/helpers.php';
if (!is_file($helpers)) {
    fwrite(STDERR, "Could not locate the OTMS backend bootstrap.\n");
    exit(1);
}
require_once $helpers;
$hours = isset($argv[1]) ? filter_var($argv[1], FILTER_VALIDATE_INT) : 24;
if (!$hours || $hours < 1 || $hours > 720) {
    fwrite(STDERR, "Usage: php tools/create_teacher_invite.php [hours: 1..720]\n");
    exit(2);
}
$raw = new_token();
$expires = gmdate('Y-m-d H:i:s', time() + $hours * 3600);
db()->prepare(
    'INSERT INTO teacher_invites (code_hash, expires_at) VALUES (?,?)'
)->execute([token_hash($raw), $expires]);
fwrite(STDOUT, "Teacher invitation (shown once): {$raw}\nExpires UTC: {$expires}\n");
