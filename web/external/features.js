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
        keepAlive: function () {
            Api.keepAlive();
        },

        repaintFriendsInvitations: function () {
            $('#invitations-scroll').empty();
            var scroll = new dw_scrollObj('invitations-vs', 'invitations-es');
            scroll.buildScrollControls('invitations-scrollbar', 'v', 'mouseover', true);
        },

        friends_cache: {},

        showFriendsBar: function (callback) {
            var show = function (items) {
                var counter = 0;
                $('.card-users').empty();
                $(items).each(function () {
                    ++counter;
                    $('.card-users').append(TemplateEngine.parseTemplate($('.friend-card-template').html(), $.extend(this, {
                        last: counter % 3 === 0 ? 'last-card' : ''
                    })));
                });

                counter = 0;
                $('.out-people').empty();
                $(Features.getNotGameFriends(Features.toIdArray(items))).each(function () {
                    ++counter;
                    $('.out-people').append(TemplateEngine.parseTemplate($('.invite-card-template').html(), $.extend(this, {
                        last: counter % 3 === 0 ? 'last-card' : ''
                    })));
                });

                callback();

                var height = $($('.friends').get(1)).height();
                VK.callMethod('resizeWindow', 800, height);
                $('.invite-button').off('click').on('click', function (e) {
                    VK.callMethod("showRequestBox", {
                        uid: $(e.target).data('id'),
                        message: "Test",
                        requestKey: "RequestKey"
                    });
                });

                var search_delay;
                $('.out-of-game-search').off('keyup').on('keyup', function (event) {
                    clearTimeout(search_delay);
                    var that = this;
                    search_delay = setTimeout(function () {
                        Features.friendsSearch.call(that, event, Features.OUT_SEARCH);
                    }, 525);
                });
            };

            if (!$.isEmptyObject(Features.friends_cache)) {
                show(Features.friends_cache);
            } else {
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

                        Features.friends_cache = items;

                        show(items);
                    });
                });
            }
        },

        IN_SEARCH: 1,
        OUT_SEARCH: 2,

        friendsSearch: function (event, type) {
            var val = $(this).val().toLowerCase();

            $('.invite-card').each(function () {
                if ($(this).find('.fr-name').html().toLowerCase().indexOf(val) === -1 && val) {
                    $(this).hide();
                } else {
                    $(this).show();
                }
            });

            Features.repaintFriendsInvitations();

            var height = $($('.friends').get(1)).height() + 800;
            VK.callMethod('resizeWindow', 800, height);
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
        },

        onLevelFinish: function (chapter, level, result, numStatic, numDynamic, attempts, timeSpent) {
            Api.finishLevel(chapter, level, result, numStatic, numDynamic, attempts, timeSpent, function (data) {
                console.log(data);
            });
        }
    }
    ;

var VKFeatures = {
    friends: null,

    initFields: function (callback) {
        VK.api("friends.get", {fields: "domain, photo_50"}, function (data) {
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

    toUserObject: function (fr) {
        return {
            id: fr.uid,
            ava: fr.photo_50,
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
    getPersonalId: function () {
        if (localStorage['userId'] == null) {
            var dt = new Date();
            localStorage['userId'] = "" + dt.getMilliseconds() + dt.getTime();
        }
        return localStorage['userId'];
    },

    initFields: function (callback) {
        Api.setPersonalId(this.getPersonalId());
        Api.setPlatform('no');
        callback();
    },

    load: function (callback) {
        this.initFields(callback)
    },

    showFriendsBar: function () {
        Api.setFriendsList([]);
        Api.initialRequest(function (data) {
            console.log('no platform: ', data);
        })
    }
};


(function () {
    switch (qs['platform']) {
        case 'vk':
            Features = extendAndOverride(Features, VKFeatures);
            break;
        default:
            Features = extendAndOverride(Features, NoFeatures);
    }

    Features.load(function () {
    });


    $(function () {
        Features.showFriendsBar();
    });

    //setInterval(Features.keepAlive, 5000);
})();