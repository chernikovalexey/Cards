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
            $this->db->prepare("SELECT * FROM tcardresults WHERE userId IN($qMarks)"));

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
        usort($scores, "DB::cmpScores");

        return $scores;
    }

    public static function cmpScores($v1, $v2)
    {
        return ($v1['value'] > $v2['value']) ? 1 : ($v1['value'] == $v2['value']) ? 0 : -1;
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
        return $r[0];
    }

    public function result($chapter, $level, $result, $numStatic, $numDynamic,array $user, $platform)
    {
        $sql = $this->db->prepare("SELECT * FROM tcardresults WHERE userId=? AND chapterId=? AND levelId=?");
        $sql->bindValue(1, $user['userId'], PDO::PARAM_INT);
        $sql->bindValue(2, $chapter, PDO::PARAM_INT);
        $sql->bindValue(3, $level, PDO::PARAM_INT);
        $sql->execute();
        if ($rslt = $sql->fetch()) {
            $sql = $this->db->prepare("UPDATE tcardresults SET result = ?, `time`=?, `numStatic`=?, `numDynamic`=? WHERE id=?");
            $sql->bindValue(1, $result, PDO::PARAM_INT);
            $sql->bindValue(2, time(), PDO::PARAM_INT);
            $sql->bindValue(3, $numStatic, PDO::PARAM_INT);
            $sql->bindValue(4, $numDynamic, PDO::PARAM_INT);
            $sql->bindParam(5, $rslt['id'], PDO::PARAM_INT);
            $sql->execute();
        } else {
            $sql = $this->db->prepare("INSERT INTO tcardresults(`userId`, `chapterId`, `levelId`, `result`, `time`, `numStatic`, `numDynamic`) VALUES(?,?,?,?,?,?,?)");
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
        $sql = $this->db->prepare("SELECT * FROM tcardusers WHERE platformUserId=? AND platformId=?");
        $sql->bindValue(1, $uid, PDO::PARAM_INT);
        $sql->bindValue(2, $platform, PDO::PARAM_STR);
        $sql->execute();

        if ($u = $sql->fetch(PDO::FETCH_ASSOC)) {
            $u['isNew'] = false;
            return $u;
        }

        $sql = $this->db->prepare("INSERT INTO tcardusers(platformId, platformUserId) VALUES (?,?)");
        $sql->bindValue(1, $platform, PDO::PARAM_STR);
        $sql->bindValue(2, $uid, PDO::PARAM_INT);

        $sql->execute();

        return array('userId' => +$this->db->lastInsertId(), 'platformId' => $platform, 'platformUserId' => $uid, 'isNew' => true);
    }
} 