function VKFeatures() {}

VKFeatures.prototype.showFriendsBar = function() {
    VK.api("friends.get", {}, function(data) {
        console.log(data);
    });
};