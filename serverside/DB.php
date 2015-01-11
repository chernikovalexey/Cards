<?php

/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 16:02
 */
class DB
{
    private $db;
    const DAY_ATTEMPTS = 200;

    public function DB(PDO $db)
    {
        $this->db = $db;
    }

    /**
     * @return \PDO
     */
    public function getDb()
    {
        return $this->db;
    }

    private function qString($n)
    {
        return str_repeat('?,', $n - 1) . '?';
    }

    private function bindArray(array $arr, $offset, $type, $selector, PDOStatement $sql)
    {
        $i = 0;
        foreach ($arr as $val) {
            $sql->bindValue($i + 1 + $offset, ($selector != null) ? $val[$selector] : $val, $type);
            $i++;
        }
        return $sql;
    }

    public function getHint($chapter, $level)
    {
        $sql = $this->db->prepare("SELECT t.data FROM tcardhints t WHERE t.chapter = ?");
        $sql->bindValue(1, $chapter, PDO::PARAM_INT);
        $sql->execute();
        $chapterHints = json_decode($sql->fetchColumn(0), true);
        return $chapterHints[$level - 1];
    }

    public function getResults(array $users, $platform, $selector = null, &$outUsers = null)
    {
        $users = $this->getPlatformUsers($users, $platform, $selector);

        $qMarks = $this->qString(count($users));

        $sql = $this->bindArray($users, 0, PDO::PARAM_INT, 'userId',
            $this->db->prepare("SELECT * FROM tcardresults WHERE userId IN($qMarks)"));

        $sql->execute();

        $arr = $sql->fetchAll(PDO::FETCH_ASSOC);
        $result = array();
        foreach ($users as $u)
            $result['u' . $u['platformUserId']] = array();

        foreach ($arr as $t) {
            if (!isset($result['u' . $users[$t['userId']]['platformUserId']]))
                $result['u' . $users[$t['userId']]['platformUserId']] = array();
            $result['u' . $users[$t['userId']]['platformUserId']][] = $t;
        }
        $outUsers = $users;
        return $result;
    }

    public function getTop(array $users, $platform)
    {
        $users = $this->getPlatformUsers($users, $platform);
        $results = $this->getResults($users, 'userId');


        $scores = array();
        foreach ($results as $r) {
            if (isset($scores[$r['userId']])) $scores[$r['userId']] = array('userId' => $users[$r['userId']]['platformUserId'], 'value' => 0);
            $scores[$r['userId']]['value'] += $r['result'];
        }
        usort($scores, function ($v1, $v2) {
            return ($v1['value'] > $v2['value']) ? 1 : ($v1['value'] == $v2['value']) ? 0 : -1;
        });

        return $scores;
    }

    public function getPlatformUsers(array $users, $platform, $selector = null)
    {
        $qMarks = $this->qString(count($users));

        $sql = $this->db->prepare("SELECT * FROM tcardusers WHERE platformUserId IN($qMarks) AND platformId=?");
        $this->bindArray($users, 0, PDO::PARAM_INT, $selector, $sql);
        $sql->bindValue(count($users) + 1, $platform, PDO::PARAM_STR);
        $sql->execute();
        $t = $sql->fetchAll(PDO::FETCH_ASSOC);
        $r = array();
        foreach ($t as $u) {
            $r[$u['userId']] = $u;
        }
        return $r;
    }

    public function getUser($userId, $platform)
    {
        $r = $this->getPlatformUsers(array($userId), $platform);
        return reset($r);
    }

    public function result($chapter, $level, $result, $numStatic, $numDynamic, array $user, $platform)
    {
        $sql = $this->db->prepare("INSERT INTO tcardresults (`userId`, `chapterId`, `levelId`, `result`, `time`, `numStatic`, `numDynamic`)
  VALUES (:user, :chapter, :level, :result, :time, :static, :dynamic)
ON DUPLICATE KEY UPDATE result = :result");
        $sql->bindValue('user', $user['userId'], PDO::PARAM_INT);
        $sql->bindValue('chapter', $chapter, PDO::PARAM_INT);
        $sql->bindValue('level', $level, PDO::PARAM_INT);
        $sql->bindValue('result', $result, PDO::PARAM_INT);
        $sql->bindValue('time', time(), PDO::PARAM_INT);
        $sql->bindValue('static', $numStatic, PDO::PARAM_INT);
        $sql->bindValue('dynamic', $numDynamic, PDO::PARAM_INT);
        $sql->execute();
        return true;
    }

    public function validateUser($uid, $platform)
    {
        $sql = $this->db->prepare("SELECT * FROM tcardusers WHERE platformUserId=? AND platformId=?");
        $sql->bindValue(1, $uid, PDO::PARAM_INT);
        $sql->bindValue(2, $platform, PDO::PARAM_STR);
        $sql->execute();

        if ($u = $sql->fetch(PDO::FETCH_ASSOC)) {
            $u['isNew'] = false;
            return $u;
        }

        $sql = $this->db->prepare("INSERT INTO tcardusers(platformId, platformUserId, balance) VALUES (?, ?, 2)");
        $sql->bindValue(1, $platform, PDO::PARAM_STR);
        $sql->bindValue(2, $uid, PDO::PARAM_INT);

        $sql->execute();

        return array('userId' => +$this->db->lastInsertId(), 'platformId' => $platform, 'platformUserId' => $uid, 'isNew' => true);
    }

    public function countAttempts(array &$user)
    {
        $user['dayAttempts'] = self::DAY_ATTEMPTS - $user['dayAttemptsUsed'];
        $user['allAttempts'] = $user['dayAttempts'] + $user['boughtAttempts'] - $user['boughtAttemptsUsed'];
    }

    public function addAttempts(array &$user, $delta)
    {
        if ($user['dayAttemptsUsed'] + $delta > self::DAY_ATTEMPTS) {
            $delta -= $user['dayAttempts'];
            $user['dayAttemptsUsed'] = self::DAY_ATTEMPTS;
            if ($user['boughtAttemptsUsed'] + $delta > $user['boughtAttempts']) {
                $user['boughtAttemptsUsed'] = $user['boughtAttempts'];
            } else {
                $user['boughtAttemptsUsed'] += $delta;
            }
        } else {
            $user['dayAttemptsUsed'] += $delta;
        }
        $this->countAttempts($user);
        $this->submitUser($user);
    }

    public function submitUser(array &$user)
    {

        $sql = $this->db->prepare("UPDATE tcardusers
                                      SET
                                        balance = ?
                                        ,boughtAttempts = ?
                                        ,dayAttemptsUsed = ?
                                        ,boughtAttemptsUsed = ?
                                         WHERE userId = ?");
        $sql->bindValue(1, $user['balance'], PDO::PARAM_INT);
        $sql->bindValue(2, $user['boughtAttempts'], PDO::PARAM_INT);
        $sql->bindValue(3, $user['dayAttemptsUsed'], PDO::PARAM_INT);
        $sql->bindValue(4, $user['boughtAttemptsUsed'], PDO::PARAM_INT);
        $sql->bindValue(5, $user['userId'], PDO::PARAM_INT);
        $sql->execute();
    }

    public function getTotalStars($userId)
    {
        $sql = $this->db->prepare("SELECT SUM(result) FROM tcardresults WHERE userId = ?");
        $sql->bindValue(1, $userId, PDO::PARAM_INT);
        $sql->execute();
        return reset($sql->fetch());
    }

    public function unlockChapter(array $user, $chapter)
    {
        $sql = $this->db->prepare("INSERT INTO tunlockedchapters(chapter, userId) VALUES(?, ?)");
        $sql->bindValue(1, $chapter, PDO::PARAM_INT);
        $sql->bindValue(2, $user['userId'], PDO::PARAM_INT);
        $sql->execute();
    }

    public function getUnlocked($userId)
    {
        $sql = $this->db->prepare("SELECT chapter FROM tunlockedchapters WHERE userId = ?");
        $sql->bindValue(1, $userId, PDO::PARAM_INT);
        $sql->execute();
        $r = array();
        foreach ($sql->fetchAll() as $c)
            $r[] = $c['chapter'];
        return $r;
    }

    private function getMaxLevel()
    {
        $arr = $this->db->query("SELECT t.chapterId, t.levelId FROM tcardresults t ORDER BY t.chapterId DESC")->fetchAll();
        usort($arr, function ($e1, $e2) {
            if ($e1['chapterId'] > $e2['chapterId'])
                return 1;
            else if ($e1['chapterId'] < $e2['chapterId'])
                return -1;
            else if ($e1['levelId'] > $e2['levelId'])
                return 1;
            else if ($e1['levelId'] > $e2['levelId'])
                return -1;
            return 0;
        });
        return $arr[count($arr) - 1];
    }

    public function getStats()
    {
        list($totalUsers, $totalAttempts) = $this->db->query("SELECT COUNT(u.userId), SUM(u.totalDayAttemptsUsed + u.boughtAttemptsUsed + u.dayAttemptsUsed) FROM tcardusers u")->fetch();
        $attemptsPerUser = $totalAttempts / $totalUsers;
        list($totalLevels, $totalStars, $totalStatic, $totalDynamic, $totalBodies) = $this->db->query("SELECT COUNT(t.id), SUM(t.result), SUM(t.numStatic), SUM(t.numDynamic), SUM(t.numDynamic + t.numStatic) FROM tcardresults t")->fetch();
        $attemptsPerLevel = $totalAttempts / $totalLevels;
        $maxLevel = $this->getMaxLevel();
        $levels = $this->db->query("SELECT SUM(t.result), t.levelId, t.chapterId FROM tcardresults t GROUP BY t.levelId * t.chapterId;")->fetchAll();
        return array(
            'users' => $totalUsers,
            'attempts' => $totalAttempts,
            'attemptsPerUser' => $attemptsPerUser,
            'attemptsPerLevel' => $attemptsPerLevel,
            'totalStars' => $totalStars,
            'totalStatic' => $totalStatic,
            'totalDynamic' => $totalDynamic,
            'totalBodies' => $totalBodies,
            'maxLevel' => $maxLevel,
            'levels' => $levels
        );
    }

    public function getConfig($key)
    {
        $sql = $this->db->prepare("SELECT value FROM tconfigurations WHERE `key` = ?");
        $sql->bindValue(1, $key, PDO::PARAM_STR);
        $sql->execute();
        list($value) = $sql->fetch();
        return $value;
    }

    public function setConfig($key, $value)
    {
        $sql = $this->db->prepare("CALL setConfig(?, ?)");
        $sql->bindValue(1, $key, PDO::PARAM_STR);
        $sql->bindValue(2, $value, PDO::PARAM_STR);
        $sql->execute();
    }

    public function getNotifications()
    {
        return $this->db->query("SELECT * FROM tcardnotifications INNER JOIN tcardusers ON tcardnotifications.userId = tcardusers.userId")->fetchAll(PDO::FETCH_ASSOC);
    }

    public function removeNotifications(array $sentNotifications)
    {
        $q = implode(',', $sentNotifications);
        $this->db->query("DELETE FROM tcardnotifications WHERE `id` IN($q)");
    }

    public function bindFriends($userId, $platform, array $friends)
    {

        $q = str_repeat('(?,?,?),', count($friends));
        $q = substr($q, 0, strlen($q) - 1);

        $query = "INSERT IGNORE INTO tcardfriendrealations(userId, platformFriendId, platformId) VALUES " . $q;
        $sql = $this->db->prepare($query);
        $i = 0;
        foreach ($friends as $f) {
            $sql->bindValue($i * 3 + 1, $userId, PDO::PARAM_INT);
            $sql->bindValue($i * 3 + 2, $f['platformUserId'], PDO::PARAM_INT);
            $sql->bindValue($i * 3 + 3, $platform, PDO::PARAM_STR);
            $i++;
        }
        $sql->execute();
    }

    public function getFriends($platformUserId)
    {
        $sql = $this->db->prepare("SELECT * FROM tcardfriendrealations t WHERE platformUserId = ?");
        $sql->bindValue(1, $platformUserId, PDO::PARAM_INT);
        $sql->execute();
        return $sql->fetchAll();
    }

    public function pushNotifications($userId, $level, $chapter, $result)
    {
        $sql = $this->db->prepare("CALL notifyFriends(?, ?, ?, ?)");
        $sql->bindValue(1, $userId, PDO::PARAM_INT);
        $sql->bindValue(2, $level, PDO::PARAM_INT);
        $sql->bindValue(3, $chapter, PDO::PARAM_INT);
        $sql->bindValue(4, $result, PDO::PARAM_INT);
        $sql->execute();
    }
} 