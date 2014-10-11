<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 16:03
 */

try {
    $db = new PDO("mysql:host=concrete.mysql.ukraine.com.ua;dbname=concrete_2048", "concrete_2048", "24evhgnm");
    $DB = new DB($db);
} catch (PDOException $e) {
    die("Error: " . $e->getMessage());
}