<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 11.11.14
 * Time: 22:20
 */

class VkPhotoUploader
{
    public static function upload($server, $filename)
    {
        echo WebClient::sendCurlFile($filename, $server);
        exit;
    }
} 