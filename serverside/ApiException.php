<?php
/**
 * Created by PhpStorm.
 * User: podko_000
 * Date: 05.06.14
 * Time: 16:15
 */

class ApiException extends Exception
{
    public $message, $api, $method, $args;
    public $error = true;

    public function ApiException($message, $api = null, $method = null, $args = null)
    {
        $this->message = $message;
        $this->api = $api;
        $this->method = $method;
        $this->args = $args;
    }
} 