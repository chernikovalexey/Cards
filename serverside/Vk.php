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
        return $this->db->getTop($friends, 'vk');
    }

    public function result($chapter, $level, $result, $user) {
        return $this->db->result($chapter, $level, $result, $user, 'vk');
    }

    public function user($uid) {
        return $this->db->user($uid, 'vk');
    }
} 