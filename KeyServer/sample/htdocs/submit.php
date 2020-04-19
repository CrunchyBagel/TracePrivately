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

$keys = $json['keys'];

if (count($keys) > 0) {
    $time = time();
    
    $db->query('BEGIN');

    $stmt = $db->prepare('INSERT INTO infected_key_submissions (status, timestamp) VALUES (:s, :t)');
    $stmt->bindValue(':s', 'P', SQLITE3_TEXT); // Pending state, must be approved
    $stmt->bindValue(':t', $time, SQLITE3_INTEGER);
    $stmt->execute();

    $submissionId = $db->lastInsertRowID();

    $stmt = $db->prepare('INSERT INTO infected_keys (infected_key, timestamp, status, submission_id) VALUES (:k, :t, :s, :i)');

    foreach ($json['keys'] as $encodedKey) {
        $stmt->bindValue(':k', $encodedKey, SQLITE3_TEXT);
        $stmt->bindValue(':t', $time, SQLITE3_INTEGER);
	$stmt->bindValue(':s', 'P', SQLITE3_TEXT); // Pending state, must be approved
	$stmt->bindValue(':i', $submissionId, SQLITE3_INTEGER);

        $stmt->execute();
    }

    $db->query('COMMIT');
}

$json = array(
    'status' => 'OK'
);

$data = json_encode($json);

header('Content-type: application/json; charset=utf-8');
echo $data;

