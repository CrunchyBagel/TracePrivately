<?php
$data = file_get_contents('php://input');
$json = json_decode($data, true);

if (!is_array($json)) {
    // TODO: Send error response
    echo "Invalid request data";
    exit;
}

// TODO: Validate the request data accordingly

// This is oversimplistic and may not work on all servers
$token = trim(`/usr/bin/uuidgen`);

// TODO: Store the token so it can be subsequently verified
// TODO: Check if there's a bearer token in this request, and if so, invalidate it.

$json = array(
    'status' => 'OK',
    'token' => $token
);

$data = json_encode($json);

header('Content-type: application/json; charset=utf-8');
echo $data;

