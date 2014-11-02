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

    public function getResults(array $users, $platform, $selector = null)
    {
        $users = $this->getPlatformUsers($users, $platform, $selector);

        $qMarks = $this->qString(count($users));

        $sql = $this->bindArray($users, 0, PDO::PARAM_INT, 'userId',
            $this->db->prepare("SELECT * FROM twocubes.tcardresults WHERE userId IN($qMarks)"));

        $sql->execute();

        $arr = $sql->fetchAll(PDO::FETCH_ASSOC);
        $result = array();
        foreach($users as $u)
            $result['u'.$u['platformUserId']] = array();

        foreach ($arr as $t) {
            if (!isset($result['u' . $users[$t['userId']]['platformUserId']]))
                $result['u' . $users[$t['userId']]['platformUserId']] = array();
            $result['u' . $users[$t['userId']]['platformUserId']][] = $t;
        }

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
        usort($scores, function($v1, $v2) {
            return ($v1['value'] > $v2['value']) ? 1 : ($v1['value'] == $v2['value']) ? 0 : -1;
        });

        return $scores;
    }

    public function getPlatformUsers(array $users, $platform, $selector = null)
    {
        $qMarks = $this->qString(count($users));

        $sql = $this->db->prepare("SELECT * FROM twocubes.tcardusers WHERE platformUserId IN($qMarks) AND platformId=?");
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

    public function result($chapter, $level, $result, $numStatic, $numDynamic,array $user, $platform)
    {
        $sql = $this->db->prepare("SELECT * FROM twocubes.tcardresults WHERE userId=? AND chapterId=? AND levelId=?");
        $sql->bindValue(1, $user['userId'], PDO::PARAM_INT);
        $sql->bindValue(2, $chapter, PDO::PARAM_INT);
        $sql->bindValue(3, $level, PDO::PARAM_INT);
        $sql->execute();
        if ($rslt = $sql->fetch()) {
            $sql = $this->db->prepare("UPDATE twocubes.tcardresults SET result = ?, `time`=?, `numStatic`=?, `numDynamic`=? WHERE id=?");
            $sql->bindValue(1, $result, PDO::PARAM_INT);
            $sql->bindValue(2, time(), PDO::PARAM_INT);
            $sql->bindValue(3, $numStatic, PDO::PARAM_INT);
            $sql->bindValue(4, $numDynamic, PDO::PARAM_INT);
            $sql->bindParam(5, $rslt['id'], PDO::PARAM_INT);
            $sql->execute();
        } else {
            $sql = $this->db->prepare("INSERT INTO twocubes.tcardresults(`userId`, `chapterId`, `levelId`, `result`, `time`, `numStatic`, `numDynamic`) VALUES(?,?,?,?,?,?,?)");
            $sql->bindValue(1, $user['userId'], PDO::PARAM_INT);
            $sql->bindValue(2, $chapter, PDO::PARAM_INT);
            $sql->bindValue(3, $level, PDO::PARAM_INT);
            $sql->bindValue(4, $result, PDO::PARAM_INT);
            $sql->bindValue(5, time(), PDO::PARAM_INT);
            $sql->bindValue(6, $numStatic, PDO::PARAM_INT);
            $sql->bindValue(7, $numDynamic, PDO::PARAM_INT);
            $sql->execute();
        }
        return true;
    }

    public function validateUser($uid, $platform)
    {
        $sql = $this->db->prepare("SELECT * FROM twocubes.tcardusers WHERE platformUserId=? AND platformId=?");
        $sql->bindValue(1, $uid, PDO::PARAM_INT);
        $sql->bindValue(2, $platform, PDO::PARAM_STR);
        $sql->execute();

        if ($u = $sql->fetch(PDO::FETCH_ASSOC)) {
            $u['isNew'] = false;
            return $u;
        }

        $sql = $this->db->prepare("INSERT INTO twocubes.tcardusers(platformId, platformUserId) VALUES (?,?)");
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
       if($user['dayAttemptsUsed'] + $delta > self::DAY_ATTEMPTS) {
           $delta -= $user['dayAttempts'];
           $user['dayAttemptsUsed'] = self::DAY_ATTEMPTS;
           if($user['boughtAttemptsUsed'] + $delta > $user['boughtAttempts']) {
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

    public function submitUser(array &$user) {

         $sql = $this->db->prepare("UPDATE twocubes.tcardusers
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
        $sql = $this->db->prepare("SELECT SUM(result) FROM twocubes.tcardresults WHERE userId = ?");
        $sql->bindValue(1, $userId, PDO::PARAM_INT);
        $sql->execute();
        return reset($sql->fetch());
    }

    public function unlockChapter($user, $chapter)
    {
        $sql = $this->db->prepare("INSERT INTO twocubes.tunlockedchapters(chapter, userId) VALUES(?, ?)");
        $sql->bindValue(1, $chapter, PDO::PARAM_INT);
        $sql->bindValue(2, $user['userId'], PDO::PARAM_INT);
        $sql->execute();
    }

    public function getUnlocked($userId)
    {
        $sql = $this->db->prepare("SELECT chapter FROM twocubes.tunlockedchapters WHERE userId = ?");
        $sql->bindValue(1, $userId, PDO::PARAM_INT);
        $sql->execute();
        $r = array();
        foreach($sql->fetchAll() as $c)
            $r[] = $c['chapter'];
        return $r;
    }
} 