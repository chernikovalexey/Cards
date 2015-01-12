<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 12.01.15
 * Time: 21:39
 */

class Localization
{

    private static $lang = 'en';
    private static $text;

    public static function  setLang($lang)
    {
        self::$lang = $lang;
        self::$text = json_decode(file_get_contents("lang/" . self::$lang . ".purchases.json"), true);
    }

    public static function getPurchaseHintsMassage($count)
    {
        return sprintf(self::$text['buyHints'] . " " . ($count > 1 ? self::$text['manyHints'] : self::$text['oneHint']), $count);
    }

    public static function getPurchaseAttemptsMessage($count)
    {
        return $count != -1 ? sprintf(self::$text['buyAttempts'], $count) : self::$text['buyUnlimitedAttempts'];
    }

    public static function getPurchaseUnlockChapter($chapterName)
    {
        return sprintf(self::$text['unlockChapter'], $chapterName);
    }
} 