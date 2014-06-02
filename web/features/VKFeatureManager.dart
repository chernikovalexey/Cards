import "dart:js";
import "dart:html";
import "FeatureManager.dart";

class VKFeatureManager extends FeatureManager {  
  VKFeatureManager() {
     context.callMethod('getScript',[window.location.protocol+"//vk.com/js/api/xd_connection.js?2']",
        new JsFunction.withThis(initialize)]);
  }
  
  void initialize() {
    
  }
}