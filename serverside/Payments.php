<?php

/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 01.11.14
 * Time: 12:54
 */
class Payments
{
    public static function create($platform, DB $db)
    {
        switch ($platform) {
            case 'vk':
                return new VKPayments($db);
            case 'fb':
                return new FBPayments($db);
        }
    }
}

interface IPayments
{
    public function perform($input);
}