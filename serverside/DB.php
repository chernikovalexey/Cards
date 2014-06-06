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
} 