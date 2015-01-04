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
        return in_array($platform, array('vk', 'fb', 'no'));
    }

    public function initialRequest(array $user, $friends)
    {
        Analytics::push(new AnalyticsEvent("session", "start", array('user' => $user['userId'])));

        if (count($friends) > 0) {
            $r = array('user' => $user, 'results' => $this->db->getResults($friends, $this->platform, null, $inGameUsers));
            $this->db->bindFriends($user['userId'], $this->platform, $inGameUsers);
            return $r;
        } else
            return array('user' => $user, 'results' => array());
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

        $this->db->addAttempts($user, $attempts);
        NotificationService::notifyFriends($this->db, $user, $level, $chapter, $result);
        if ($this->platform == 'vk') {
            VKServerMethods::getInstance($this->db)->setUserLevel($user['platformUserId'], $chapter * $level);
        }
        return array('result' => $this->db->result($chapter, $level, $result, $numStatic, $numDynamic, $user, $this->platform));
    }

    public function getHint(array $user, $chapter, $level)
    {
        if ($user['balance'] > 0) {
            $user['balance']--;
            $this->db->submitUser($user);
            return array("user" => $user, "hint" => $this->db->getHint($chapter, $level));
        }
        throw new ApiException("To use hint you must have at least 1 hint on your balance!");
    }

    public function addAttempts(array $user, $numAttempts)
    {

        $user['allAttempts'] -= $numAttempts;
        $this->db->addAttempts($user, $numAttempts);
        return $user;
    }

    public function payments()
    {
        $payments = Payments::create($this->platform, $this->db);
        return $payments->perform($_POST);
    }

    public function fbGetChapterUnlockOg(array $user, $chapter)
    {
        require_once 'Payments.php';
        $p = new FBPayments($this->db);
        $p->getChapterUnlockOg($user, $chapter);
        return null;
    }

    public function chapters(array $user)
    {
        $total = $this->db->getTotalStars($user['userId']);
        $unlocked = $this->db->getUnlocked($user['userId']);
        $chapters = json_decode(file_get_contents(CHAPTER_FILE), true);
        $r = array();
        foreach ($chapters['chapters'] as $i => $c) {
            $c['unlocked'] = $c['unlock_stars'] <= $total || in_array($i + 1, $unlocked);
            $r[] = $c;
        }
        return array('chapters' => $r);
    }

    public function getUser(array $user)
    {
        return $user;
    }

    public function uploadPhoto(array $user, $server, $base64Image)
    {
        $filename = FileHelper::saveTempImage($base64Image);
        return $this->uploadPhotoInternal($user, $server, $filename);
    }

    public function uploadPhotoReserved(array $user, $server, $reservedName)
    {

        $reservedNames = array(
            'logo' => SITE_PATH . "web/img/logo.png",
            'promo' => SITE_PATH . "web/img/logo@2x.png"
        );
        return $this->uploadPhotoInternal($user, $server, $reservedNames[$reservedName]);
    }

    public function stats()
    {
        header('Content-Type: application/json');
        return $this->db->getStats();
    }

    private function uploadPhotoInternal(array $user, $server, $filename)
    {

        $server = urldecode($server);

        switch ($this->platform) {
            case 'vk':
                VkPhotoUploader::upload($server, $filename);
                break;
        }
        return null;
    }

    public function sendNotifications()
    {

        return NotificationService::send($this->db);
    }

    public function save($user, $data)
    {
        echo "save";
        var_dump(file_put_contents("chapter1.full.json", $_POST['arguments'][1]));
    }

    public function checkPlatform(&$arguments)
    {
        switch ($this->platform) {
            case 'vk':
                if (md5(VK_APP_ID . '_' . $arguments['userId'] . '_' . VK_SECRET_KEY) != $arguments['auth_key'])
                    throw new ApiException("auth_key is invalid! Connection is untrusted. Check iframe VK parameters!");
                unset($arguments['auth_key']);
                return;
        }
    }
}