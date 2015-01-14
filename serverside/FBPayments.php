<?php
header("Content-Type: application/json; encoding=utf-8");


class FBPayments implements IPayments
{
    const SECRET_KEY = 'b414d64c9dc377b6393f93c1be235472';
    const APP_ACCESS_TOKEN = "614090422033888|yFA8WD5EifKvWR_5aRyYWYWx8OQ";
    const VERIFICATION_TOKEN = 'uEV9yPIrxGkApJTtBrAflZIRqTuZda';
    const GRAPH_API_URL = 'https://graph.facebook.com/%s?access_token=%s';
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

    public function perform()
    {
        $this->input = $_REQUEST;
        $this->route();
        /*if (!$this->validate())
            return array('response' => $this->response);

        return array('response' => $this->route());*/
    }

    private function getGraphUrl($id)
    {

        return sprintf(self::GRAPH_API_URL, $id, self::APP_ACCESS_TOKEN);
    }

    private function getChapterProduct($productUrl)
    {
        $arg = 'arguments=';
        $url = json_decode(urldecode(substr($productUrl, strpos($productUrl, $arg) + strlen($arg))), true);
        //file_put_contents('file.json', print_r($url, true));
        return array('chapter', $url['chapter'], '1');
    }

    private function getProduct($product)
    {
        $url = $product;
        $end = end(explode('/', $product));
        $product = reset(explode('.', $end));
        switch ($product) {
            case '1-h':
                return array('hint', 1);
            case '2-h':
                return array('hint', 2);
            case '5-h':
                return array('hint', 5);
            case '10-h':
                return array('hint', 10);
            case '10-a':
                return array('attempt', 10);
            case '25-a':
                return array('attempt', 25);
            case '50-a':
                return array('attempt', 50);
            case '100-a':
                return array('attempt', 100);
            case '-1-a':
                return array('attempt', -1);
            default:
                return $this->getChapterProduct($url);
        }
    }

    private function route()
    {
        switch ($this->input['hub_mode']) {
            case 'subscribe':
                echo $this->input['hub_challenge'];
                exit;

        }
        $this->request = json_decode(file_get_contents("php://input"), true);

        $data = json_decode(WebClient::downloadString($this->getGraphUrl($this->request['entry'][0]['id'])), true);
        $user = $this->db->getUser($data['user']['id'], 'fb');
        $action = $data['actions'][0];
        if ($action['type'] == 'charge' && $action['status'] == 'completed') {
            $product = $this->getProduct($data['items'][0]['product']);
            $this->order($user, $product);
        }

        //file_put_contents("file.txt", );
    }

    private function order(array $user, array $product)
    {

        //file_put_contents("file.json" ,json_encode($product)."\r\n".json_encode($user));
        switch ($product[0]) {
            case 'hint':
                $user['balance'] += $product[1];
                break;
            case 'attempt':
                if ($product[1] != -1)
                    $user['boughtAttempts'] += $product[1];
                else
                    $user['boughtAttempts'] = -1;
                break;
            case 'chapter':
                $this->db->unlockChapter($user, $product[1]);
                break;
        }
        if ($product[0] == 'hint' || $product[0] == 'attempt')
            $this->db->submitUser($user);
    }

    private function getChapterPrice(array $chapter, $totalStars)
    {

        $toUnlock = $chapter['unlock_stars'];
        $coefficient = ($toUnlock - $totalStars) / floatval($toUnlock);

        if ($coefficient < 0.2)
            return 1;
        else if ($coefficient < 0.33)
            return 3;
        else if ($coefficient < 0.5)
            return 5;
        else
            return 10;
    }

    public function getChapterUnlockOg(array $user, $chapter)
    {
        $totalStars = $this->db->getTotalStars($user['userId']);
        $chapters = json_decode(file_get_contents(CHAPTER_FILE), true);
        $chapter = $chapters['chapters'][$chapter - 1];
        $price = $this->getChapterPrice($chapter, $totalStars);
        $actual_link = "http://{$_SERVER[HTTP_HOST]}{$_SERVER[REQUEST_URI]}";
        echo sprintf('<head prefix="og: http://ogp.me/ns# fb: http://ogp.me/ns/fb#">
                <meta property="og:type" content="og:product" />
                <meta property="og:title" content="Unlock %s chapter!"/>
                <meta property="og:plural_title" content="%s"/>
                <meta property="og:image" content="http://friendsmashsample.herokuapp.com/friendsmash_social_persistence_payments/images/coin.64.png" />
                <meta property="og:url" content="%s"/>
                <meta property="og:description" content="Unlock chapter: %s!"/>
                <meta property="product:price:amount" content="%s"/>
                <meta property="product:price:currency" content="USD"/>
              </head>', $chapter['name'], $chapter['name'], $actual_link, $chapter['name'], $price);
        exit;
    }
}
