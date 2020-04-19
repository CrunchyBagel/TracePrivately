#!/usr/bin/php
<?php

if ($argc != 2) {
    echo sprintf("Usage: %s [submission id]\n", $argv[0]);
    exit(1);
}

$submissionId = (int) $argv[1];

if ($submissionId <= 0) {
    echo sprintf("Invalid submission ID\n");
    exit(2);
}

$path = realpath(dirname(__FILE__) . '/../data/trace.sqlite');
$db = new SQLite3($path, SQLITE3_OPEN_READWRITE);

$db->query('BEGIN');

$status = 'A';
$oldStatus = 'P';

$stmt = $db->prepare('UPDATE infected_key_submissions SET status = :s WHERE submission_id = :i AND status = :o');
$stmt->bindValue(':s', $status, SQLITE3_TEXT);
$stmt->bindValue(':o', $oldStatus, SQLITE3_TEXT);
$stmt->bindValue(':i', $submissionId, SQLITE3_INTEGER);
$stmt->execute();

$stmt = $db->prepare('UPDATE infected_keys SET status = :s WHERE submission_id = :i AND status = :o');
$stmt->bindValue(':s', $status, SQLITE3_TEXT);
$stmt->bindValue(':o', $oldStatus, SQLITE3_TEXT);
$stmt->bindValue(':i', $submissionId, SQLITE3_INTEGER);
$stmt->execute();

$numChanges = $db->changes();

$db->query('COMMIT');

echo sprintf("Number of keys updated: %d\n", $numChanges);
