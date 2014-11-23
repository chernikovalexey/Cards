<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 16:03
 */

function startsWith($haystack, $needle)
{
    $length = strlen($needle);
    return (substr($haystack, 0, $length) === $needle);
}

function endsWith($haystack, $needle)
{
    $length = strlen($needle);
    if ($length == 0) {
        return true;
    }

    return (substr($haystack, -$length) === $needle);
}

try {
    $connectionString = "mysql:host=104.131.127.236;dbname=twocubes";
    if (endsWith(SITE_PATH, 'test')) {
        $connectionString .= '.test';
        define('TEST', true, true);
    } else {
        define('TEST', false, true);
    }
    $db = new PDO($connectionString, "twocubes", "oxB3uUWg");
    $DB = new DB($db);
} catch (PDOException $e) {
    die("Error: " . $e->getMessage());
}