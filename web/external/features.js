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
                        var items = [];

                        for (var key in data) {
                            items.push(
                                extendAndOverride(
                                    {id: +key.substr(1), result: Features.calcResult(data[key])},
                                    Features.getUserObject(+key.substr(1)))
                            );
                        }

                        var obj;
                        TemplateEngine.parseTemplate($('.friends-bar-template').html(), obj = {
                            users: (function () {
                                var r = "";
                                $(items).each(function () {
                                    r += TemplateEngine.parseTemplate($('.friend-card-template').html(), this);
                                    console.log(this);
                                });
                                return r;
                            })(),
                            invite: (function () {
                                var r = "";
                                $(Features.getNotGameFriends(Features.toIdArray(items))).each(function () {
                                    r += TemplateEngine.parseTemplate($('.invite-card-template').html(), this);
                                });
                                return r;
                            })()
                        });
                        console.log(obj);
                    });
                }
            )
            ;
        },

        calcResult: function (data) {
            var r = 0;
            $(data).each(function () {
                r += +this.result;
            });
            return r;
        },

        toIdArray: function (data) {
            var r = [];
            $(data).each(function () {
                r.push(this.uid || this.id);
            });

            return r;
        }
    }
    ;

var VKFeatures = {
    friends: null,

    initFields: function (callback) {
        VK.api("friends.get", {fields: "domain, photo_100"}, function (data) {
            Api.setFriendsList(Features.toIdArray(data.response));
            Features.friends = data.response;

            Api.setPersonalId(qs['viewer_id']);
            Api.setPlatform('vk');
            callback();
        });
    },


    getNotGameFriends: function (inGameFriendsIds) {
        var r = [];
        $(Features.friends).each(function () {
            if ($.inArray(this.uid, inGameFriendsIds))
                r.push(Features.toUserObject(this));
        });

        return r;
    },

    toUserObject: function(fr) {
        return {
            id: fr.uid,
            ava: fr.photo_100,
            name: fr.first_name,
            surname: fr.last_name
        };
    },

    getUserObject: function (id) {
        for (var i = 0; i < this.friends.length; i++) {
            var fr = this.friends[i];
            if (fr.uid == id) {
                return this.toUserObject(fr);
            }
        }
    },

    load: function (callback) {
        $.getScript(document.location.protocol + "//vk.com/js/api/xd_connection.js?2", callback);
    }
};

var NoFeatures = {
    initFields: function (callback) {
        callback();
    },

    load: function (callback) {
        callback();
    },

    showFriendsBar: function () {
    }
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


