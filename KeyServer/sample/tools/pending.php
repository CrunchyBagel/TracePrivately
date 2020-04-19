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

if (count($ids) == 0) {
    echo "No submissions awaiting approval.\n";
}
else {
    echo "Pending submission IDs:\n\n";

    foreach ($ids as $id) {
        echo sprintf("\t%d\n", $id);
    }

    echo "\nUse the approve.php script to approve submissions.\n";
}


