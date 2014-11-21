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

    private function getChapterProduct($ch, $productUrl)
    {
        $url = parse_url($productUrl);
        $chapterId = +end(explode('=', $url['query']));
        $s = reset(explode('-', $ch));
        return array('chapter', $chapterId, $s);
    }

    private function getProduct($product)
    {
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
            default:
                return $this->getChapterProduct($end, $product);
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

        switch ($product[0]) {
            case 'hint':
                $user['balance'] += $product[1];
                break;
            case 'attempt':
                $user['boughtAttempts'] += $product[1];
                break;
            case 'chapter':
                $this->db->unlockChapter($user, $product[1]);
                break;
        }
        if ($product[0] == 'hint' || $product[0] == 'attempt')
            $this->db->submitUser($user);
    }
}
