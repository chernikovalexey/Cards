<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 15:40
 */

function __autoload($className)
{
    if (file_exists($className . ".php"))
        require_once $className . ".php";
    else
    {
        die("Class not found! $className");
    }
}

class Router
{
    private $db;

    public function Router(DB $db)
    {
        $this->db = $db;
    }

    public function route()
    {
        $arguments = json_decode(stripslashes($_REQUEST['arguments']), true);
        list($platform, $method) = explode('.', isset($_POST['method']) ? $_POST['method'] : $_GET['method']);
        if (!Api::validatePlatform($platform)) {
            return new ApiException('404 platform not found', $platform, $method, $arguments);
        }

        $Api = new Api($this->db, $platform);
        if ($method == "payments") {
            return $Api->payments();
        }
        try {
            $rm = new ReflectionMethod($Api, $method);
            //todo: Add clause if user not valid
            $user = $this->db->validateUser($arguments['userId'], $platform);
            $this->db->countAttempts($user);
            $arguments['userId'] = $user; // что бы при вызове invokeArgs этот параметр шел первым, в методы Апи уже попадет как массив $user

            Analytics::init($user['userId'], $platform);

            if ($user['isNew'])
                Analytics::push(new AnalyticsEvent("user", "new", array('platform' => $platform)));
            $result = $rm->invokeArgs($Api, $arguments);
            return $this->prepare($result);
        } catch (ApiException $e) {
            $e->api = $platform;
            $e->args = $arguments;
            $e->method = $method;
            return $e;
        } catch (Exception $e) {
            return new ApiException("404 method not found", $platform, $method, $arguments);
        }
    }

    public function prepare($data)
    {
        $result = array();
        foreach ($data as $key => $value) {
            if(is_array($value))
                $result[$key] = $this->prepare($value);
            else
                $result[$key] = is_numeric($value) ? +$value : $value;
        }

        return $result;
    }
} 