import "dart:js";

class VKApi {
  VKApi() {
     context.callMethod('VK.init', [() {print("VK Api initalized successfully");}]);
  }
}