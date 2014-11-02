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
        define("CHAPTER_FILE", "../web/levels/chapters.json", true);
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
            return array('user' => $user, 'results' =>  $this->db->getResults($friends, $this->platform));
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

        $this->db->addAttempts($user ,$attempts);
        return array('result' => $this->db->result($chapter, $level, $result, $numStatic, $numDynamic, $user, $this->platform));
    }

    public function getHint(array $user, $chapter, $level)
    {
        if ($user['balance'] > 0) {
            $chapter = intval($chapter);
            $levelIndex = intval($level) - 1;
            $filename = "private/hints/" . $chapter . ".json";
            if (file_exists($filename)) {
                $chapterHints = json_decode(file_get_contents($filename), true);
                if (!isset($chapterHints[$levelIndex]))
                    throw new ApiException("There is no hint for this level in specified file!");
                $user['balance']--;
                $this->db->submitUser($user);

                return array("user" => $user, "hint" => $chapterHints[$levelIndex]);
            }
            throw new ApiException("Hint file is not available, chapter name is not valid!");
        }
        throw new ApiException("To use hint you must have at least 1 hint on your balance!");
    }

    public function addAttempts(array $user, $numAttempts) {

        $user['allAttempts'] -= $numAttempts;
        $this->db->addAttempts($user, $numAttempts);
        return $user;
    }

    public function payments() {

        $payments = Payments::create($this->platform, $this->db);
        return $payments->perform($_POST);
    }

    public function chapters(array $user) {

        $total = $this->db->getTotalStars($user['userId']);
        $unlocked = $this->db->getUnlocked($user['userId']);
        $chapters = json_decode(file_get_contents(CHAPTER_FILE), true);
        $r = array();
        foreach($chapters['chapters'] as $i => $c) {
            $c['unlocked'] = $c['unlock_stars'] < $total ||  in_array($i + 1, $unlocked);
            $r[] = $c;
        }
        return array('chapters' => $r);
    }
} 