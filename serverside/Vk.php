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
} 