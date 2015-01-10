<?php
header("Content-Type: application/json; encoding=utf-8");

class VKPayments implements IPayments
{
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

        if ($sig != md5($str . VK_SECRET_KEY)) {
            $this->response['error'] = array(
                'error_code' => 10,
                'error_msg' => 'Несовпадение вычисленной и переданной подписи запроса.',
                'critical' => true
            );
            return false;
        }
        return true;
    }

    public function perform()
    {
        $this->input = $_POST;
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

    private function getPrice($type, $count)
    {
        switch ($type) {
            case 'h':
                switch ($count) {
                    case 1:
                        return 4;
                    case 2:
                        return 8;
                    case 5:
                        return 16;
                    case 10:
                        return 24;
                }
                break;
            case 'c':
                switch ($count) {
                    case 0:
                        return 10;
                    case 2:
                        return 30;
                    case 3:
                        return 50;
                    case 5:
                        return 100;
                }
                break;
            case 'a':
                switch ($count) {
                    case 10:
                        return 2;
                    case 25:
                        return 4;
                    case 50:
                        return 8;
                    case 100:
                        return 12;
                    case -1:
                        return 80;
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
        define("BASE_URL", "http://twopeoplesoftware.com/twocubes28340jfddv03jfd/web/img/purchases/");
        define("ATTEMPTS_IMG", BASE_URL . "attempts_%s.png");
        define("HINTS_IMG", BASE_URL . "hints_%s.png");
        define("UNLOCK", BASE_URL . "unlock.png");
        // todo: Add a special method to get this info from item id
        $info = $this->getItemInfo($item);

        switch ($info['type']) {
            case 'h':
                return array(
                    //todo: make item id int
                    'item_id' => $item,
                    'title' => "Buy {$info['count']}-hints-pack!",
                    'photo_url' => sprintf(HINTS_IMG, $info['count']),
                    'price' => $this->getPrice($info['type'], $info['count'])
                );
            case 'a':
                $info['countname'] = ($info['count'] == -1) ? 'unlimited' : strval($info['count']);
                return array(
                    'item_id' => $item,
                    'title' => "Buy {$info['countname']}-attempts-pack!",
                    'photo_url' => sprintf(ATTEMPTS_IMG, $info['count']),
                    'price' => $this->getPrice($info['type'], $info['count'])
                );
            case 'c':
                $data = $this->getChapterInfo($info['platformUserId'], $info['count']);
                return array(
                    'item_id' => $item,
                    'title' => "Unlock chapter #" . $info['count'] . " " . $data['name'],
                    'photo_url' => UNLOCK,
                    'price' => $data['price']
                );
        }
    }

    private function orderStatusChange($status)
    {
        if ($status != 'chargeable')
            return array(
                'error_code' => 10,
                'error_msg' => 'Передано непонятно что вместо chargeable.',
                'critical' => true
            );

        // todo: Add special table to mysql to store data about purchases
        $info = $this->getItemInfo($this->input['item']);
        $user = $this->db->getUser($info['platformUserId'], 'vk');
        switch ($info['type']) {
            case 'a':
                if ($info['count'] != -1)
                    $user['boughtAttempts'] += $info['count'];
                else
                    $user['boughtAttempts'] = -1;
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
