<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 16:01
 */

class Api {
    protected $db;

    public function Api(DB $db) {
        $this->db = $db;
    }
} 