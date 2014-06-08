<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 16:03
 */

class Vk extends Api {
    public function Vk($db) {
        parent::Api($db);
    }

    public function getFriendsData(array $friends) {
        $qMarks = str_repeat('?,', count($friends) - 1) . '?';
        $sql = $this->db->getDb()->prepare("SELECT * FROM tcardusers WHERE platformUserId IN($qMarks)");
        foreach($friends as $i=>$f) {
            $sql->bindParam($i+1, $f, PDO::PARAM_INT);
        }
        $sql->execute();
        return $sql->fetchAll();
    }
} 