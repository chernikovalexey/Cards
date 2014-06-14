<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 13.06.14
 * Time: 18:49
 */

class Analytics {
    private static $userId;
    private static $events;

    private static $game_key = "65bfc1c766b5b05e4c7cbc4da3a56259";
    private static $secret_key = "c080ac51b515df82ce4a529c2bbbdbe39ffec13b";
    private static $url = "http://api.gameanalytics.com/1";
    private static $category="design";

    public static function init($userId) {
        self::$userId = $userId;
        self::$events = array();
    }

    public static function push(AnalyticsEvent $evt) {
        self::$events[] = $evt;
        $values= array("user_id" => self::$userId, "session_id" => session_id(), "build" => "serverGA");

        $json_message = json_encode($values);
        $authorization = md5($json_message . "" . self::$secret_key);

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, self::$url ."/". self::$game_key ."/". self::$category);

        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $json_message);
        curl_setopt($ch, CURLOPT_HTTPHEADER, array("Authorization: ".$authorization));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);

        $result = curl_exec($ch);
        $curl_info = curl_getinfo($ch);

        echo $result;
        curl_close($ch);
    }

    public static function flush() {

    }
}

class AnalyticsEvent {
    private $category, $type, $data;

    public function __construct($category, $type, $data) {
        $this->category = $category;
        $this->type = $type;
        $this->data = $data;
    }

    public function toArray() {
        return array_merge(array('event_id'=>$this->category.':'.$this->type), $this->data);
    }
}