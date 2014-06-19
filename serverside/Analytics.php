<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 13.06.14
 * Time: 18:49
 */

class Analytics
{
    private static $userId;
    private static $platform;
    private static $events;

    private static $game_key = "2adf5d6837a8a8b744a94772176f654d";
    private static $secret_key = "fe9befdac51d6ce91a6b62bed933e59751078c47";
    private static $url = "http://api.gameanalytics.com/1";
    private static $category = "design";

    public static function init($userId, $platform)
    {
        self::$userId = $userId;
        self::$platform = $platform;
        self::$events = array();
    }

    public static function push(AnalyticsEvent $evt)
    {
        self::$events[] = $evt;
    }

    public static function flush()
    {

        $values = array("user_id" => self::$userId, "session_id" => session_id(), "build" => "serverGA", "platform" => self::$platform);
        $arr = array();
        foreach (self::$events as $evt) {
            $arr[] = array_merge($evt->toArray(), $values);
        }

        $json_message = json_encode($arr);

        $authorization = md5($json_message . "" . self::$secret_key);

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, self::$url . "/" . self::$game_key . "/" . self::$category);

        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $json_message);
        curl_setopt($ch, CURLOPT_HTTPHEADER, array("Authorization: " . $authorization));
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);

        $result = curl_exec($ch);
        $curl_info = curl_getinfo($ch);

        curl_close($ch);
    }
}

class AnalyticsEvent
{
    private $category, $type, $data;

    public function __construct($category, $type, $data)
    {
        $this->category = $category;
        $this->type = $type;
        $this->data = $data;
    }

    public function toArray()
    {
        return array_merge(array('event_id' => $this->category . ':' . $this->type), $this->data);
    }
}