import "dart:html";
import "FeatureManager.dart";
import "VKFeatureManager.dart";

class FeatureFactory {
    static FeatureManager create() {
        Uri url = Uri.parse(window.location.href);
        String platform = url.queryParameters['platform'];
        switch(platform)
        {
          case 'vk':
            return new VKFeatureManager();
        }
    }
}
