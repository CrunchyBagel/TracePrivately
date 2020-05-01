#!/usr/bin/php
<?php

$path = realpath(dirname(__FILE__) . '/../data/trace.sqlite');
$db = new SQLite3($path, SQLITE3_OPEN_READWRITE);

$stmt = $db->prepare('SELECT submission_id FROM infected_key_submissions WHERE status = :s');
$stmt->bindValue(':s', 'P', SQLITE3_TEXT);

$result = $stmt->execute();

$ids = array();

while (($row = $result->fetchArray(SQLITE3_NUM))) {
    $ids[] = $row[0];
}

$command = sprintf('%s/approve.php', dirname(__FILE__));

foreach ($ids as $id) {
	$cmd = sprintf('%s %d', escapeshellcmd($command), $id);
//	echo $cmd . "\n";
	system($cmd);
}

