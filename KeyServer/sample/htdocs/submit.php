<?php
require_once('shared.php');

if (!isValidBearer($db)) {
    sendJsonErrorResponse(401, 'Invalid bearer token');
    exit;
}

$data = file_get_contents('php://input');
$json = json_decode($data, true);

if (!is_array($json)) {
    sendInvalidRequestMessage("Invalid request data");
    exit;
}

if (!array_key_exists('keys', $json)) {
    sendInvalidRequestMessage("Keys parameter is missing");
    exit;
}

if (!is_array($json['keys'])) {
    sendInvalidRequestMessage("Keys isn't an array");
    exit;
}

$keys = $json['keys'];

// TODO: Only use this if a valid identifier isn't specified in the request
$uniqueId = trim(`/usr/bin/uuidgen`); // TODO: This may not work on all systems

if (count($keys) > 0) {
    $time = time();
    
    $db->query('BEGIN');

    $stmt = $db->prepare('INSERT INTO infected_key_submissions (client_identifier, status, status_updated, timestamp) VALUES (:i, :s, :d, :t)');
    $stmt->bindValue(':i', $uniqueId, SQLITE3_TEXT);
    $stmt->bindValue(':s', 'P', SQLITE3_TEXT); // Pending state, must be approved
    $stmt->bindValue(':d', $time, SQLITE3_INTEGER);
    $stmt->bindValue(':t', $time, SQLITE3_INTEGER);
    $stmt->execute();

    $submissionId = $db->lastInsertRowID();

    $stmt = $db->prepare('INSERT INTO infected_keys (infected_key, rolling_start_number, timestamp, status, status_updated, submission_id) VALUES (:k, :r, :t, :s, :d, :i)');

    // It's possible there are no keys with a submission, and a placeholder record is created so subsequent keys can be recorded
    foreach ($json['keys'] as $key) {
	$encodedKey = $key['d'];
	$rollingStartNumber = $key['r'];

        $stmt->bindValue(':k', $encodedKey, SQLITE3_TEXT);
	$stmt->bindValue(':r', $rollingStartNumber, SQLITE3_INTEGER);
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

sendJsonResponse(200, $json);

