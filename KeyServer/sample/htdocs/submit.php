<?php
$path = realpath(dirname(__FILE__) . '/../data/trace.sqlite');
$db = new SQLite3($path, SQLITE3_OPEN_READWRITE);

// TODO: Validate bearer token and throw 401 if not valid

$data = file_get_contents('php://input');
$json = json_decode($data, true);

// TODO: Implement proper error responses

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

// TODO: This may not work on all systems
// TODO: Record this with the submission so it can be found again later
// TODO: Only use this if a valid identifier isn't specified in the request
$uniqueId = trim(`/usr/bin/uuidgen`);

if (count($keys) > 0) {
    $time = time();
    
    $db->query('BEGIN');

    $stmt = $db->prepare('INSERT INTO infected_key_submissions (status, status_updated, timestamp) VALUES (:s, :d, :t)');
    $stmt->bindValue(':s', 'P', SQLITE3_TEXT); // Pending state, must be approved
    $stmt->bindValue(':d', $time, SQLITE3_INTEGER);
    $stmt->bindValue(':t', $time, SQLITE3_INTEGER);
    $stmt->execute();

    $submissionId = $db->lastInsertRowID();

    $stmt = $db->prepare('INSERT INTO infected_keys (infected_key, timestamp, status, status_updated, submission_id) VALUES (:k, :t, :s, :d, :i)');

    foreach ($json['keys'] as $encodedKey) {
        $stmt->bindValue(':k', $encodedKey, SQLITE3_TEXT);
        $stmt->bindValue(':t', $time, SQLITE3_INTEGER);
	$stmt->bindValue(':s', 'P', SQLITE3_TEXT); // Pending state, must be approved
        $stmt->bindValue(':d', $time, SQLITE3_INTEGER);
	$stmt->bindValue(':i', $submissionId, SQLITE3_INTEGER);

        $stmt->execute();
    }

    $db->query('COMMIT');
}

$json = array(
    'status' => 'OK',
    'identifier' => $uniqueId
);

$data = json_encode($json);

header('Content-type: application/json; charset=utf-8');
echo $data;

