<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 15:36
 */

session_start();

require_once "Router.php";
require_once "dbconnect.php";

header("Content-type: application/json");
$router = new Router($DB);
$result = $router->route();
Analytics::flush();

echo json_encode($result);