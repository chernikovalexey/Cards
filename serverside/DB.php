<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 16:02
 */

class DB {
    private $db;
    public function DB(PDO $db) {
        $this->db = $db;
    }

    /**
     * @return \PDO
     */
    public function getDb()
    {
        return $this->db;
    }

    private function qString($n) {
        return str_repeat('?,', $n-1) . '?';
    }

    private function bindArray(array $arr, $offset,$type, $selector, PDOStatement $sql) {
        $i=0;
        foreach($arr as $val) {
            $sql->bindValue($i+1+$offset, ($selector!=null)?$val[$selector]:$val, $type);
            $i++;
        }
        return $sql;
    }

    public function getResults(array $users, $selector=null) {
        $qMarks = $this->qString(count($users));

        $sql = $this->bindArray($users,0, PDO::PARAM_INT, $selector,
            $this->db->prepare("SELECT * FROM tcardresults WHERE userId IN($qMarks)"));

        $sql->execute();

        return $sql->fetchAll(PDO::FETCH_ASSOC);
    }

    public function getTop(array $users, $platform) {
        $users = $this->getPlatformUsers($users, $platform);
        $results = $this->getResults($users, 'userId');


        $scores = array();
        foreach($results as $r) {
            if(isset($scores[$r['userId']])) $scores[$r['userId']] = array('userId'=>$users[$r['userId']]['platformUserId'], 'value'=>0);
            $scores[$r['userId']]['value'] += $r['result'];
        }
        usort($scores, "DB::cmpScores");

        return $scores;
    }

    public static function cmpScores($v1, $v2) {
        return ($v1['value']>$v2['value'])?1:($v1['value']==$v2['value'])?0:-1;
    }

    public function getPlatformUsers(array $users, $platform, $selector=null) {
        $qMarks = $this->qString(count($users));

        $sql = $this->db->prepare("SELECT * FROM tcardusers WHERE platformUserId IN($qMarks) AND platformId=?");
        $this->bindArray($users, 0, PDO::PARAM_INT, $selector, $sql);
        $sql->bindValue(count($users)+1, $platform, PDO::PARAM_STR);
        $sql->execute();
        $t =  $sql->fetchAll(PDO::FETCH_ASSOC);
        $r = array();
        foreach($t as $u) {
            $r[$u['userId']] = $u;
        }
        return $r;
    }
} 