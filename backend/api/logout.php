<?php
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$token = bearer_token();
if ($token) db()->prepare('DELETE FROM sessions WHERE token = ?')->execute([$token]);
send(['ok' => true]);
