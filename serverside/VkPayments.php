<?php
header("Content-Type: application/json; encoding=utf-8");

class VKPayments implements IPayments
{
    const SECRET_KEY = '8EBAedkNndi88TRrWyYj';
    private $input;
    private $response;
    /**
     * @var $db DB
     */
    private $db;

    public function VKPayments(DB $db)
    {
        $this->db = $db;
    }

    private function validate()
    {
        $sig = $this->input['sig'];
        unset($this->input['sig']);
        ksort($this->input);
        $str = '';
        foreach ($this->input as $k => $v) {
            $str .= $k . '=' . $v;
        }

        if ($sig != md5($str . self::SECRET_KEY)) {
            $this->response['error'] = array(
                'error_code' => 10,
                'error_msg' => 'Несовпадение вычисленной и переданной подписи запроса.',
                'critical' => true
            );
            return false;
        }
        return true;
    }

    public function perform($input)
    {
        $this->input = $input;
        if (!$this->validate())
            return array('response' => $this->response);

        return array('response' => $this->route());
    }

    private function route()
    {
        switch ($this->input['notification_type']) {
            case 'get_item':
            case 'get_item_test':
                return $this->getItem($this->input['item']);
            case 'order_status_change':
            case 'order_status_change_test':
                return $this->orderStatusChange($this->input['status']);
        }
        return null;
    }

    private function getPrice($hints)
    {
        switch ($hints) {
            case 10:
                return 1;
            case 25:
                return 2;
            case 50:
                return 4;
            case 100:
                return 6;
        }
        return -1;
    }

    private function getItem($item)
    {
        // todo: Add a special method to get this info from item id
        list($hints, $userId) = explode('.', $item);
        return array(
            //todo: make item id int
            'item_id' => $item,
            'title' => "Buy {$hints}-hints-pack!",
            'photo_url' => 'http://thumbs.dreamstime.com/thumb_370/1235836831WEhmZf.jpg',
            'price' => $this->getPrice($hints)
        );
    }

    private function orderStatusChange($status)
    {
        if ($status != 'chargeable')
            return array(
                'error_code' => 100,
                'error_msg' => 'Передано непонятно что вместо chargeable.',
                'critical' => true
            );

        // todo: Add special table to mysql to store data about purchases
        list($hints, $userId) = explode('.', $this->input['order_id']);
        $user = $this->db->getUser($userId, 'vk');
        $user['balance'] += $hints;
        $this->db->submitUser($user);
        return array(
            'order_id' => $this->input['order_id'],
            'app_order_id' => 1
        );
    }
}
