<?php
$path = realpath(dirname(__FILE__) . '/../data/trace.sqlite');
$db = new SQLite3($path, SQLITE3_OPEN_READWRITE);

$time = time() - (86400 * 14);

$stmt = $db->prepare('SELECT infected_key FROM infected_keys WHERE timestamp >= :t');
$stmt->bindValue(':t', $time, SQLITE3_INTEGER);

$result = $stmt->execute();


$keys = array();

while (($row = $result->fetchArray(SQLITE3_NUM))) {
    $keys[] = $row[0];
}

$json = array(
    'status' => 'OK',
    'keys' => $keys
);

//$data = json_encode($json, JSON_PRETTY_PRINT);
$data = json_encode($json);

header('Content-type: application/json; charset=utf-8');
echo $data;
