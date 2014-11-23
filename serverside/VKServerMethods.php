<?php

class Param
{
    public $name, $value;

    public function Param($name, $value)
    {
        $this->name = $name;
        $this->value = $value;
    }

    public static function ZeroParam()
    {
        return new Param("param", "value");
    }
}

class VKServerMethods
{
    const APP_ID = VK_APP_ID;
    const APP_SECRET = VK_SECRET_KEY;
    const API_URL = "https://api.vk.com/method/";
    const QUERY_STRING = "https://api.vk.com/method/%s?%s&access_token=%s&client_secret=%s";

    /**@var $instance VKServerMethods */
    private static $instance;

    private $accessToken;

    private function VKServerMethods($accessToken)
    {
        $this->accessToken = $accessToken;
    }

    public static function getInstance()
    {
        if (self::$instance != null)
            return self::$instance;
        return self::login();
    }

    public static function login()
    {
        $loginLink = 'https://oauth.vk.com/access_token?client_id=' . self::APP_ID . '&client_secret=' . self::APP_SECRET . '&grant_type=client_credentials';
        if ($accessToken = DBVkData::getToken()) {
            self::$instance = new VKServerMethods($accessToken);
            return self::getInstance();
        } else {
            $obj = json_decode(WebClient::downloadString($loginLink), true);
            DBVkData::setToken($obj['access_token']);
            self::$instance = new VKServerMethods($obj['access_token']);
            return self::getInstance();
        }
    }

    private function query($method)
    {
        $params = "";
        $args = func_get_args();
        array_shift($args);
        foreach ($args as $arg) {
            if ($arg->name != 'uids' && $arg->name != 'user_ids' && $arg->name != 'params')
                $params .= $arg->name . '=' . urlencode($arg->value);
            else
                $params .= $arg->name . '=' . ($arg->value);
            if ($arg != $args[count($args) - 1]) {
                $params .= '&';
            }
        }

        $str = sprintf(self::QUERY_STRING, $method, $params, $this->accessToken, VKServerMethods::APP_SECRET);
        return WebClient::downloadString($str);
    }

    public function getAppBalance()
    {
        $arr = json_decode($this->query("secure.getAppBalance", Param::ZeroParam()));
        if (!isset($arr->response))
            $arr->response = 0;
        return $arr->response;
    }

    public function getTransactionsHistory()
    {
        return $this->query("secure.getTransactionsHistory", Param::ZeroParam());
    }

    public function getSmsHistory($uid, $dateFrom, $dateTo, $limit)
    {
        return $this->query("secure.getSMSHistory",
            new Param('uid', $uid),
            new Param('date_from', $dateFrom),
            new Param('date_to', $dateTo),
            new Param('limit', $limit)
        );
    }

    public function sendSmsNotification($uid, $message)
    {
        $var = $this->query("secure.sendSMSNotification",
            new Param('uid', $uid),
            new Param('message', $message)
        );
        return $var;
    }

    public function sendNotification($uids, $message)
    {
        return $this->query("secure.sendNotification",
            new Param("uids", $uids),
            new Param("message", $message)
        );
    }

    public function setCounter($uid, $counter)
    {
        return $this->query("secure.setCounter",
            new Param('uid', $uid),
            new Param('counter', $counter));
    }

    public function usersGet($uids, $fields)
    {
        echo "users get\r\n";
        $url = self::API_URL . 'users.get';

// use key 'http' even if you send the request to https://...
        $options = array(
            'http' => array(
                'header' => "Content-type: application/x-www-form-urlencoded\r\n",
                'method' => 'POST',
                'content' => http_build_query(array('user_ids' => implode(',', $uids), 'fields' => $fields)),
            ),
        );
        $context = stream_context_create($options);
        $result = file_get_contents($url, false, $context);
        return json_decode($result, true);

        //return json_decode($this->query("users.get", new Param('user_ids',implode(',',$uids)), new Param('fields', $fields)), true);
    }
}