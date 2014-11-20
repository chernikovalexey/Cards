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

        if (count($friends) > 0)
            return array('user' => $user, 'results' => $this->db->getResults($friends, $this->platform));
        else
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

    public function addAttempts(array $user, $numAttempts)
    {

        $user['allAttempts'] -= $numAttempts;
        $this->db->addAttempts($user, $numAttempts);
        return $user;
    }

    public function payments()
    {
        /*if ($_SERVER['REQUEST_METHOD'] === 'GET' && $_GET['hub_mode'] === 'subscribe') {
            $app_id = 614090422033888;
            $app_secret = "b414d64c9dc377b6393f93c1be235472";
            $res = file_get_contents("https://graph.facebook.com/oauth/access_token?client_id=" . $app_id . "&client_secret=" . $app_secret . "&grant_type=client_credentials");
            list($temp, $access_token) = explode('=', $res);
            $res2 = WebClient::postData("https://graph.facebook.com/" . $app_id . "/subscriptions", array(
                "access_token" => $access_token,
                "object" => "user",
                "callback_url" => "http://twopeoplesoftware.com/twocubes/serverside/index.php?method=fb.payments",
                "fields" => "pic",
                "verify_token" => $_GET['hub_verify_token']
            ));
            echo $res2;
            return $res2;
        }*/

        $verify_token = "bsdkm341omdssdfg4";

        $method = $_SERVER['REQUEST_METHOD'];

        if ($method == 'GET' && $_GET['hub_verify_token'] === $verify_token) {
            echo $_GET['hub_challenge'];
            exit();
        }
        else if( $method == 'GET') {
            echo "<h1>REAL TIME UPDATES</h1>";
        }

        if ($method == 'POST') {
            $time_now = date("Y-m-d H:i:s");
            $updates = json_decode(file_get_contents("php://input"), true);

            log($time_now . " " . json_encode($updates) ."\n\n\n", 3, "rtudata.txt");
            log($time_now . " " . json_encode($_REQUEST) ."\n", 3, "rtudata.txt");
            log($time_now . " " . json_encode($_SERVER) ."\n", 3, "rtudata.txt");
        }

        //$payments = Payments::create($this->platform, $this->db);
        //return $payments->perform($_POST);
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

        $reservedNames = array('logo' => SITE_PATH . "web/img/logo.png");
        return $this->uploadPhotoInternal($user, $server, $reservedNames[$reservedName]);
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
}