import "dart:js";
import "dart:html";
import "dart:async";
import "FeatureManager.dart";
import "VKApi.dart";

class VKFeatureManager extends FeatureManager {  
  VKApi VK;
  
  VKFeatureManager() {
    VK = new VKApi();
    VK.onLoad = () {
      JsObject obj = new JsObject(context['VKFeatures']);
      obj.callMethod('showFriendsBar');
    };
  }
  
}