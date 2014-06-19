<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 16:01
 */

class Api
{
    protected $db;
    private $platform;

    public function Api(DB $db, $platform)
    {
        $this->db = $db;
        $this->platform = $platform;

    }

    public static function validatePlatform(&$platform)
    {
        $platform = strtolower($platform);
        return in_array($platform, array('vk','no'));
    }

    public function initialRequest(array $user, $friends)
    {
        Analytics::push(new AnalyticsEvent("session", "start", array('user' => $user)));
        return $this->db->getResults($friends, $this->platform);
    }

    public function finishLevel(array $user, $chapter, $level, $result, $attempts, $timeSpent)
    {
        Analytics::push(new AnalyticsEvent("level", "finish", array(
            'area' => 'c' . $chapter . 'l' . $level,
            'chapter' => $chapter,
            'level' => $level,
            'result' => $result,
            'attempts' => $attempts,
            'timeSpent' => $timeSpent
        )));

        return array('result' => $this->db->result($chapter, $level, $result, $user, $this->platform));
    }
} 