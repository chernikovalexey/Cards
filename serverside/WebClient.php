<?php
/**
 * Created by JetBrains PhpStorm.
 * User: podko_000
 * Date: 14.06.13
 * Time: 11:55
 * To change this template use File | Settings | File Templates.
 */

class WebClient
{
    public static function downloadString($url)
    {
        $c = curl_init($url);
        curl_setopt($c, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($c, CURLOPT_RETURNTRANSFER, 1);

        $result = curl_exec($c);
        if (!$result) {
            echo curl_error($c);
        }
        curl_close($c);
        return $result;
    }

    public static function getXPath($link)
    {
        $html = WebClient::downloadString($link);
        $dd = new DOMDocument();
        error_reporting(E_ERROR);
        $dd->loadHTML($html, LIBXML_NOWARNING);
        error_reporting(E_ALL ^ E_STRICT);
        $xPath = new DOMXPath($dd);
        return $xPath;
    }

   public static function sendCurlFile($path, $server)
   {
       $ch = curl_init($server);

       curl_setopt($ch, CURLOPT_POST, 1);
       curl_setopt($ch, CURLOPT_POSTFIELDS, array('photo' => '@' . $path));
       curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);

       return curl_exec($ch);
   }
}