<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 11.11.14
 * Time: 22:29
 */

class FileHelper {
    public static function saveTempImage($base64Image) {

        $filename = tempnam(sys_get_temp_dir(), "FileHelper.saveTempImage.") . '.png';
        file_put_contents($filename, base64_decode($base64Image));
        return $filename;
    }
}
