<?php
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
        return array('vk' => $vk);
        //$this->sendVk($vk);
    }

    private function sendVk($vk)
    {
        $methods = VKServerMethods::getInstance($this->db);
        $data = $methods->usersGet($this->getIds($vk), 'online,online_mobile');
        $byUserId = $this->groupBy($vk, 'platformUserId');
        $forSend = array();
        foreach ($data['response'] as $u) {
            if ($u['online'] == 1 && (!isset($u['online_mobile']) || $u['online_mobile'] != 1)) {
                $r = $byUserId[$u['uid']][0]['reason'];
                if (!isset($forSend[$r]))
                    $forSend[$r] = array();
                $forSend[$r][] = $byUserId[$u['uid']][0];
            }
        }

        $sentNotifications = array();
        foreach ($forSend as $reason => $reasonArray) {
            if ($reason != 3) //needs extra data
                $methods->sendNotification($this->getIds($reasonArray), $this->getMessage($reason, 'ru'));
            else {
                foreach ($reasonArray as $r) {
                    $methods->sendNotification($r['platformUserId'], $this->getMessage($reason, 'ru', $r['data']));
                }
            }
            $sentNotifications = array_merge($this->getValues($reasonArray, 'id'), $sentNotifications);
        }

        $this->db->removeNotifications($sentNotifications);
        return count($sentNotifications);
    }

    private $messages;

    private function getMessage($reason, $lang)
    {
        if ($this->messages == null) {
            $this->messages = array();
        }
        if (!isset($this->messages[$lang])) {
            $this->messages[$lang] = json_decode(file_get_contents("lang/" . $lang . '.json'));
        }

        return $this->messages[$lang][$reason];
    }

    private function internalNotifyFriends(array $user, $level, $chapter, $result)
    {
        $this->db->pushNotifications($user['userId'], $level, $chapter, $result);
    }
}