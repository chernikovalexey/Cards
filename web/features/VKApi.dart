import "dart:js";
import "dart:async";
import "dart:html";

class VKApi {
  VKApi() {
    beginLoad();
  }
  
  Function onLoad;
  
  void initialize() {
      new Timer(new Duration(microseconds: 100), isReady);
  }
  
  void callMethod(String method, Function callback) {
    context['VK'].callMethod(method, [new JsFunction.withThis((o1){callback();})]);    
  }
  
  void isReady() {
     if(context['VK']!=null) {
       print("VK SKD is loaded");
       if(context['VKFeatures']!=null)
       {
         callMethod("init", loaded);
         return;
       }
     }
     new Timer(new Duration(microseconds: 100), isReady); 
  }
  
  void beginLoad() {
    print("begin load VK SDK");
    ScriptElement el = new ScriptElement();
    el.setAttribute("type", "text/javascript");
    el.setAttribute("src", window.location.protocol+"//vk.com/js/api/xd_connection.js?2");
    querySelector("head").append(el);
    
    el = new ScriptElement();
    el.setAttribute("type", "text/javascript");
    el.setAttribute("src", "external/vkFeatures.js");
    querySelector("head").append(el);
    initialize();
  }
  
  void loaded() {
    print("VK SDK initialized");
    if(onLoad!=null)
       onLoad();
  }
}