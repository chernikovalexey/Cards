<?php
header("Content-Type: application/json; encoding=utf-8");



class FBPayments implements IPayments
{
    const SECRET_KEY = 'b414d64c9dc377b6393f93c1be235472';
    private $input;
    private $request;
    private $response;
    /**
     * @var $db DB
     */
    private $db;

    public function FBPayments(DB $db)
    {
        $this->db = $db;
    }

    private function parse_signed_request($signed_request, $secret) {
        list($encoded_sig, $payload) = explode('.', $signed_request, 2);

        // Decode the data
        $sig = $this->base64_url_decode($encoded_sig);
        $data = json_decode(base64_url_decode($payload), true);

        if (strtoupper($data['algorithm']) !== 'HMAC-SHA256') {
            error_log('Unknown algorithm. Expected HMAC-SHA256');
            return null;
        }

        // check signature
        $expected_sig = hash_hmac('sha256', $payload, $secret, $raw = true);
        if ($sig !== $expected_sig) {
            error_log('Bad Signed JSON signature!');
            return null;
        }
        return $data;
    }

    private function base64_url_decode($input) {
        return base64_decode(strtr($input, '-_', '+/'));
    }

    private function validate()
    {
        $this->$request = parse_signed_request($_POST['signed_request'], self::SECRET_KEY);

        if ($this->$request == null) {
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
        switch ($this->input['method']) {
            case 'payments_get_item_price':
                return $this->getItem($this->input['item']);
            case 'order_status_change':
            case 'order_status_change_test':
                return $this->orderStatusChange($this->input['status']);
        }
        return null;
    }

    private function getPrice($type, $count)
    {
        switch ($type) {
            case 'h':
                switch ($count) {
                    case 1:
                        return 0.5;
                    case 2:
                        return 1;
                    case 5:
                        return 2;
                    case 10:
                        return 3;
                }
                break;
            case 'c':
                switch ($count) {
                    case 0:
                        return 1;
                    case 2:
                        return 3;
                    case 3:
                        return 5;
                    case 5:
                        return 10;
                }
                break;
            case 'a':
                switch ($count) {
                    case 10:
                        return 0.25;
                    case 25:
                        return 1;
                    case 50:
                        return 2;
                    case 100:
                        return 3;
                }
        }

        return -1;
    }

    private function getChapterPrice($platformUserId, $chapter)
    {
        $user = $this->db->getUser($platformUserId, 'vk');
        $totalStars = $this->db->getTotalStars($user['userId'], $chapter);
        $toUnlock = $chapter['unlock_stars'];

        $coefficient = ($toUnlock - $totalStars) / floatval($toUnlock);

        if ($coefficient < 0.2)
            return 10;
        else if ($coefficient < 0.33)
            return 30;
        else if ($coefficient < 0.5)
            return 50;
        else
            return 100;
    }

    private function getChapterInfo($platformUserId, $chapter)
    {

        $chapters = json_decode(file_get_contents(CHAPTER_FILE), true);

        $chapter = $chapters['chapters'][$chapter - 1];
        return array(
            'name' => $chapter['name'],
            'price' => $this->getChapterPrice($platformUserId, $chapter)
        );
    }

    private function getItemInfo($item)
    {
        list($type, $count, $platformUserId) = explode('.', $item);
        return array('type' => $type, 'count' => $count, 'platformUserId' => $platformUserId);
    }

    private function getItem($item)
    {
        // todo: Add a special method to get this info from item id
        $info = $this->getItemInfo($item);

        $user_currency = $this->request['payment']['user_currency'];
        $user_country = $this->request['user']['country'];

        $item['product'] = $this->request['payment']['product'];

        $quantity = $this->request['payment']['quantity'];


        switch ($info['type']) {
            case 'h':
                return array(
                    //todo: make item id int
                    'item_id' => $item,
                    'title' => "Buy {$info['count']}-hints-pack!",
                    'photo_url' => 'http://thumbs.dreamstime.com/thumb_370/1235836831WEhmZf.jpg',
                    'price' => $this->getPrice($info['type'], $info['count'])
                );
            case 'a':
                return array(
                    'item_id' => $item,
                    'title' => "Buy {$info['count']}-attempts-pack!",
                    'photo_url' => 'http://thumbs.dreamstime.com/thumb_370/1235836831WEhmZf.jpg',
                    'price' => $this->getPrice($info['type'], $info['count'])
                );
            case 'c':
                $data = $this->getChapterInfo($info['platformUserId'], $info['count']);
                return array(
                    'item_id' => $item,
                    'title' => "Unlock chapter #" . $info['count'] . " " . $data['name'],
                    'photo_url' => 'http://thumbs.dreamstime.com/thumb_370/1235836831WEhmZf.jpg',
                    'price' => $data['price']
                );
        }
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
        $info = $this->getItemInfo($this->input['item']);
        $user = $this->db->getUser($info['platformUserId'], 'vk');
        switch ($info['type']) {
            case 'a':
                $user['boughtAttempts'] += $info['count'];
                break;
            case 'h':
                $user['balance'] += $info['count'];
                break;
            case 'c':
                $this->unlockChapter($user, $info['count']);
        }
        $this->db->submitUser($user);

        return array(
            'order_id' => $this->input['order_id'],
            'app_order_id' => 1
        );
    }

    private function unlockChapter(array $user, $chapter)
    {
        $this->db->unlockChapter($user, $chapter);
    }
}
