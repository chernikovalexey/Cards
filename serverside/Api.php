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
        return in_array($platform, array('vk', 'no'));
    }

    public function initialRequest(array $user, $friends)
    {
        Analytics::push(new AnalyticsEvent("session", "start", array('user' => $user['userId'])));

        if (count($friends) > 0)
            return $this->db->getResults($friends, $this->platform);
        else
            return array();
    }

    public function keepAlive(array $user)
    {
        Analytics::push(new AnalyticsEvent("connection", "keepAlive", array('user' => $user['userId'])));
        return array('result' => true);
    }

    public function finishLevel(array $user, $chapter, $level, $result, $numStatic, $numDynamic, $attempts, $timeSpent)
    {
        Analytics::push(new AnalyticsEvent("level", "finish", array(
            'area' => 'c' . $chapter . 'l' . $level,
            'chapter' => $chapter,
            'level' => $level,
            'result' => $result,
            'attempts' => $attempts,
            'timeSpent' => $timeSpent
        )));

        return array('result' => $this->db->result($chapter, $level, $result, $numStatic, $numDynamic, $user, $this->platform));
    }

    public function getHint(array $user, $chapter, $level)
    {
        if ($user['balance'] > 0) {
            $chapter = intval($chapter);
            $level = intval($level);
            $filename = "private/hints/" . $chapter . ".json";
            if (file_exists($filename)) {
                $chapterHints = json_decode(file_get_contents($filename), true);
                if (!isset($chapterHints[$level]))
                    throw new ApiException("There is no hint for this level in specified file!");
                $user['balance']--;
                $this->db->setUserBalance($user);

                return array("user" => $user, "hint" => $chapterHints[$level]);
            }
            throw new ApiException("Hint file is not available, chapter name is not valid!");
        }
        throw new ApiException("To use hint you must have at least 1 hint on your balance!");
    }
} 