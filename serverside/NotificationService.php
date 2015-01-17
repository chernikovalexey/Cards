<?php
use Facebook\FacebookCanvasLoginHelper;
use Facebook\FacebookRequestException;
use Facebook\FacebookSession;

/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 23.11.14
 * Time: 16:02
 */

class NotificationService
{

    /**
     * @var $db DB
     */
    private $db;

    public function  NotificationService(DB $db)
    {
        $this->db = $db;
    }


    public static function send($db)
    {
        $service = new self($db);
        return $service->internalSend();
    }

    public static function notifyFriends(DB $db, array $user, $level, $chapter, $result)
    {
        $service = new self($db);
        $service->internalNotifyFriends($user, $level, $chapter, $result);
    }

    private function select(&$array, callable $condition)
    {
        $r = array();
        foreach ($array as $e)
            if ($condition($e))
                $r[] = $e;
        return $r;
    }

    private function getIds(&$data)
    {
        return $this->getValues($data, 'platformUserId');
    }

    private function getValues(&$array, $key)
    {
        $r = array();
        foreach ($array as $a) {
            $r[] = $a[$key];
        }
        return $r;
    }

    private function selectByKey(&$array, $key, $value)
    {
        return $this->select($array, function ($e) use ($key, $value) {
            return $e[$key] == $value;
        });
    }

    private function groupBy(&$array, $key)
    {
        $result = array();
        foreach ($array as $a) {
            if (!isset($result[$a[$key]]))
                $result[$a[$key]] = array();
            $result[$a[$key]][] = $a;
        }
        return $result;
    }

    private function internalSend()
    {

        $notifications = $this->db->getNotifications();
        $platforms = $this->groupBy($notifications, 'platformId');
        $vk = $this->sendVk($platforms['vk']);
        $fb = $this->sendFb($platforms['fb']);
        return array('vk' => $vk, 'fb' => $fb);
        //$this->sendVk($vk);
    }

    private function sendFb($fb)
    {
        ini_set('display_errors', 1);
        ini_set('display_startup_errors', 1);
        error_reporting(-1);
        var_dump($fb);
        require_once "Analytics.php";
        require_once "ApiException.php";
        require_once "Payments.php";
        require_once "FBPayments.php";
        require_once "lib/autoload.php";
        FacebookSession::setDefaultApplication('614090422033888', 'b414d64c9dc377b6393f93c1be235472');
        $session = new FacebookSession('614090422033888|b414d64c9dc377b6393f93c1be235472');
        //var_dump($session);

        if ($session) {
            foreach ($fb as $user) {
                $userId = $user['platformUserId'];
                $request = new Facebook\FacebookRequest(
                    $session,
                    'POST',
                    "/$userId/notifications",
                    array(
                        'href' => '/',
                        'template' => $this->getMessage($user['reason'], 'en', $user['data']),
                    )
                );
                $this->db->removeNotifications(array($user['id']));
                try {
                    $response = $request->execute();
                } catch (Exception $e) {
                    var_dump($e);
                }
            }
        }

        return 0;
    }

    private function sendVk($vk)
    {
        $methods = VKServerMethods::getInstance($this->db);
        $data = $methods->usersGet($this->getIds($vk), 'online,online_mobile,name');
        $byUserId = $this->groupBy($vk, 'platformUserId');
        $forSend = array();
        foreach ($data['response'] as $u) {
            if ($u['online'] == 1 && (!isset($u['online_mobile']) || $u['online_mobile'] != 1)) {
                $r = $byUserId[$u['uid']][0]['reason'];
                if (!isset($forSend[$r]))
                    $forSend[$r] = array();
                $forSend[$r][] = $byUserId[$u['uid']][0];
            }
        };
        var_dump($forSend);
        $sentNotifications = array();
        foreach ($forSend as $reason => $reasonArray) {
            if ($reason != 2) //needs extra data
                echo $methods->sendNotification($this->getIds($reasonArray), $this->getMessage($reason, 'ru'));
            else {
                foreach ($reasonArray as $r) {
                    $methods->sendNotification($r['platformUserId'], $reason == 2 ? $this->getMessage($reason, 'ru', $r['data']) : $r['data']);
                }
            }
            $sentNotifications = array_merge($this->getValues($reasonArray, 'id'), $sentNotifications);
        }

        $this->db->removeNotifications($sentNotifications);
        return count($sentNotifications);
    }

    private $messages;

    private function getMessage($reason, $lang, $data = array())
    {
        if ($this->messages == null) {
            $this->messages = array();
        }
        if (!isset($this->messages[$lang])) {
            $this->messages[$lang] = json_decode(file_get_contents("lang/" . $lang . '.json'));
        }

        return sprintf($this->messages[$lang][$reason], $data);
    }

    private function internalNotifyFriends(array $user, $level, $chapter, $result)
    {
        $this->db->pushNotifications($user['userId'], $level, $chapter, $result);
    }
}