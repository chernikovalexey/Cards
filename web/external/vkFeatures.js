function VKFeatures() {}

VKFeatures.prototype.showFriendsBar = function() {
    VK.api("friends.get", {}, function(data) {
        WebApi("vk.getFriendsData", {"friends": data}, function() {

        });
    });
};