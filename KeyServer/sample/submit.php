<?php
$path = realpath(dirname(__FILE__) . '/../data/trace.sqlite');
$db = new SQLite3($path, SQLITE3_OPEN_READWRITE);

$data = file_get_contents('php://input');
$json = json_decode($data, true);

if (!is_array($json)) {
    echo "Invalid request data";
    exit;
}

if (!array_key_exists('keys', $json)) {
    echo "Keys parameter is missing";
    exit;
}

if (!is_array($json['keys'])) {
    echo "Keys isn't an array";
    exit;
}

$stmt = $db->prepare('INSERT INTO infected_keys (infected_key, timestamp) VALUES (:k, :t)');
$time = time();

foreach ($json['keys'] as $encodedKey) {
    $stmt->bindValue(':k', $encodedKey, SQLITE3_TEXT);
    $stmt->bindValue(':t', $time, SQLITE3_INTEGER);

    $stmt->execute();
}

$json = array(
    'status' => 'OK'
);

$data = json_encode($json);

header('Content-type: application/json; charset=utf-8');
echo $data;
