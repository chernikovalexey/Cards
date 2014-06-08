<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 15:40
 */

function __autoload($className) {
    if(file_exists($className.".php"))
        require_once $className.".php";
}

class Router {
    private $db;
    public function Router(DB $db) {
        $this->db = $db;
    }

    public function route() {
        list($api, $method) = explode('.',$_POST['method']);
        $arguments = json_decode(stripslashes($_POST['arguments']), true);
        $api = ucfirst($api);

        if(file_exists($api.".php")) {
            $Api = new $api($this->db);
            try {
                $m = new ReflectionMethod($api, $method);
                try {
                    $result = $m->invokeArgs($Api, $arguments);
                    return $result;
                } catch(ApiException $e) {
                    return $e;
                }

            } catch(Exception $e) {}
        }
        return new ApiException("404 method not found", $api, $method, $arguments);
    }
} 