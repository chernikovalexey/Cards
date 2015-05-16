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
    $connectionString = "mysql:host=%host%;dbname=%dbname%";
    if (!endsWith(SITE_PATH, '28340jfddv03jfd' . DIRECTORY_SEPARATOR)) {
        $connectionString .= '.test';
        define('TEST', true, true);
    } else {
        define('TEST', false, true);
    }

    if (TEST) {
        define("VK_SECRET_KEY", "%vksecretkeytest%", true);
        define("VK_APP_ID", 0, true);
    } else {

        define("VK_SECRET_KEY", "%vksecretkey%", true);
        define("VK_APP_ID", 0, true);
    }

    $db = new PDO($connectionString, "%username%", "%pass%");
    $DB = new DB($db);
} catch (PDOException $e) {
    die("Error: " . $e->getMessage());
}
