/**
 * Created by podko_000 on 13.06.14.
 */

var qs = (function (a) {
    if (a == "") return {};
    var b = {};
    for (var i = 0; i < a.length; ++i) {
        var p = a[i].split('=');
        if (p.length != 2) continue;
        b[p[0]] = decodeURIComponent(p[1].replace(/\+/g, " "));
    }
    return b;
})(window.location.search.substr(1).split('&'));

var extendAndOverride = function (o1, o2) {
    for (var key in o2) {
        o1[key] = o2[key];
    }
    return o1;
};


var Features = {
    showFriendsBar: function () {
        Features.initFields(function () {
            Api.initialRequest(function (data) {
                console.log(data);
            });
        });
    }
};

var VKFeatures = {
    initFields: function (callback) {
        VK.api("friends.get", {}, function (data) {
            Api.setFriendsList(data.response);
            Api.setPersonalId(qs['viewer_id']);
            Api.setPlatform('vk');
            callback();
        });
    },

    load: function(callback) {
        $.getScript(document.location.protocol+"//vk.com/js/api/xd_connection.js?2", callback);
    }
};

var NoFeatures = {
    initFields: function(callback) {
        callback();
    },

    load: function(callback) {
        callback();
    },

    showFriendsBar: function() {}
};


(function () {
    switch (qs['platform']) {
        case 'vk':
            Features = extendAndOverride(Features, VKFeatures);
            break;
        default:
            Features = NoFeatures;
    }

    Features.load(Features.showFriendsBar);
})();


