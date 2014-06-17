<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 16:01
 */

class Api {
    protected $db;
    private $platform;

    public function Api(DB $db, $platform) {
        $this->db = $db;
        $this->platform = $platform;

    }

    public static function validatePlatform(&$platform)
    {
        $platform = strtolower($platform);
        return in_array($platform, array('vk'));
    }

    public function initialRequest($userId, $friends) {
        $user = $this->db->validateUser($userId, $this->platform);
        Analytics::init($userId);

        if($user['isNew'])
            Analytics::push(new AnalyticsEvent("user", "new", array('platform'=>$this->platform)));

        Analytics::push(new AnalyticsEvent("session", "start", array('user'=>$userId)));
        return $this->db->getResults($friends, $this->platform);
    }
} 