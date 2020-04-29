<?php
require_once('shared.php');

$data = file_get_contents('php://input');
$json = json_decode($data, true);

if (!is_array($json)) {
    sendInvalidRequestMessage("Invalid request data");
    exit;
}

// TODO: Validate the request data accordingly

$token   = trim(`/usr/bin/uuidgen`); // This may not work on all servers
$now     = time();
$expires = $now + (7 * 86400);

$db->query('BEGIN');

$stmt = $db->prepare('INSERT INTO auth_keys (timestamp_created, timestamp_expired, auth_token) VALUES (:c, :e, :t)');
$stmt->bindValue(':c', $now, SQLITE3_INTEGER);
$stmt->bindValue(':e', $expires, SQLITE3_INTEGER);
$stmt->bindValue(':t', $token, SQLITE3_TEXT);
$stmt->execute();

$db->query('COMMIT');

// TODO: Check if there's a bearer token in this request, and if so, invalidate it.

$json = array(
    'status'     => 'OK',
    'token'      => $token,
    'expires_at' => $expires
);

sendJsonResponse(200, $json);

