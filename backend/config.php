<?php
// PDO connection for the OTMS database.
$OTMS_DB_HOST = '127.0.0.1';
$OTMS_DB_NAME = 'otms';
$OTMS_DB_USER = 'root';
$OTMS_DB_PASS = '';

function db(): PDO {
    static $conn = null;
    if ($conn === null) {
        global $OTMS_DB_HOST, $OTMS_DB_NAME, $OTMS_DB_USER, $OTMS_DB_PASS;
        $conn = new PDO(
            "mysql:host=$OTMS_DB_HOST;dbname=$OTMS_DB_NAME;charset=utf8mb4",
            $OTMS_DB_USER,
            $OTMS_DB_PASS,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]
        );
    }
    return $conn;
}
