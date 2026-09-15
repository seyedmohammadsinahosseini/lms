<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
send(['user' => public_user($user)]);
