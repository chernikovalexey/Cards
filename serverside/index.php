<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 15:36
 */

require_once "Router.php";
require_once "dbconnect.php";

$router = new Router($DB);
$result = $router->route();
header("Content-type: application/json");
echo json_encode(get_object_vars($result));