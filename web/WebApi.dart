import "dart:js";

class WebApi {
    WebApi() {
      
    }
    
    static void getFriendsData() {
      (context['Api'] as JsObject).callMethod('initialRequest');
    }
}
