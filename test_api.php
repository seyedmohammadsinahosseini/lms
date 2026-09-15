<?php
$context = stream_context_create([
    'http' => [
        'method' => 'POST',
        'header' => 'Content-Type: application/json',
        'content' => json_encode(['email' => 'teacher@otms.test', 'password' => 'password'])
    ]
]);
echo file_get_contents('http://localhost:8000/api/login.php', false, $context);