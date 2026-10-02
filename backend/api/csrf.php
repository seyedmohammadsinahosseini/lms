<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
send(['csrf_token' => rotate_csrf_token($user)]);
