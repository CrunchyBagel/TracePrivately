<?php

$path = realpath(dirname(__FILE__) . '/../data/trace.sqlite');
$db = new SQLite3($path, SQLITE3_OPEN_READWRITE);


function sendJsonResponse($code, $json) {
    http_response_code($code);
    $data = json_encode($json);
    header('Content-type: application/json; charset=utf-8');
    echo $data;
}

function sendJsonErrorResponse($code, $string) {
    $json = array(
	'status' => 'ERROR',
	'message' => $string
    );

    sendJsonResponse($code, $json);
}

function sendInvalidRequestMessage($string) {
    sendJsonErrorResponse(400, $string);
}

function isValidBearer($db) {
    $headers = apache_request_headers();

    $header = '';
    
    foreach ($headers as $k => $v) {
	if (strtolower($k) == 'authorization') {
	    $header = $v;
	    break;
	}
    }

    if (!preg_match('/^bearer +([a-z0-9-]+)$/i', $header, $matches)) {
	return false;
    }

    $token = trim($matches[1]);

    if (strlen($token) == 0) {
	return false;
    }

    $stmt = $db->prepare('SELECT count(*) FROM auth_keys WHERE auth_token = :t AND timestamp_expired >= :e');
    $stmt->bindValue(':t', $token, SQLITE3_TEXT);
    $stmt->bindValue(':e', time(), SQLITE3_INTEGER);

    $result = $stmt->execute();

    if (($row = $result->fetchArray(SQLITE3_NUM)) !== false) {
        $count = (int) $row[0];
	return $count > 0;
    }

    return false;
}

