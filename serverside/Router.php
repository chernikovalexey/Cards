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
        $arguments = json_decode(stripslashes($_POST['arguments']), true);
        list($platform,$method) = explode('.',$_POST['method']);
        if(!Api::validatePlatform($platform)) {
            return new ApiException('404 platform not found', $platform, $method, $arguments);
        }

        $Api = new Api($this->db,$platform);

        $rm = new ReflectionMethod($Api, $method);
        try {
            //todo: Add clause if user not valid
            $user = $this->db->validateUser($arguments['userId'], $platform);
            $arguments['userId'] = $user;

            Analytics::init($user['userId']);

            if($user['isNew'])
                Analytics::push(new AnalyticsEvent("user", "new", array('platform'=>$platform)));

            return $rm->invokeArgs($Api, $arguments);
        } catch(Exception $e) {
            return new ApiException("404 method not found", $platform, $method, $arguments);
        }
    }
} 