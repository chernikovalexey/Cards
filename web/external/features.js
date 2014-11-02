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

    user: {},
    chapters: {},
    friends_in_game: [],

    showFinishedFriends: function (chapter, level, callback) {
        $('.finished-friends').empty();
        $.each(Features.chapters[chapter][level], function (k, v) {
            $('.finished-friends').append(TemplateEngine.parseTemplate($('.finished-friend-template').html(), $.extend(v, {
                id: k.replace("u", "")
            })));
        });

        callback();
    },

    showFriendsBar: function (callback) {
        if (!$.isEmptyObject(Features.friends_in_game)) {
            var counter = 0;
            $('.card-users').empty();
            $(Features.friends_in_game).each(function () {
                ++counter;
                $('.card-users').append(TemplateEngine.parseTemplate($('.friend-card-template').html(), $.extend(this, {
                    pos: counter,
                    last: counter % 3 === 0 ? 'last-card' : ''
                })));
            });

            counter = 0;
            $('.out-people').empty();
            $(Features.getNotGameFriends(Features.toIdArray(Features.friends_in_game))).each(function () {
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
            $('.search-input').off('keyup').on('keyup', function (event) {
                clearTimeout(search_delay);
                var that = this;
                search_delay = setTimeout(function () {
                    var type = Features.OUT_SEARCH;
                    if ($(that).hasClass('in-game-search')) {
                        type = Features.IN_SEARCH;
                    }
                    Features.friendsSearch.call(that, event, type);
                }, 525);
            });
        }
    },

    IN_SEARCH: 1,
    OUT_SEARCH: 2,

    friendsSearch: function (event, type) {
        var val = $(this).val().toLowerCase();

        $(type === Features.OUT_SEARCH ? '.invite-card' : '.friend-card').each(function () {
            if ($(this).find('.fr-name').html().toLowerCase().indexOf(val) === -1 && val) {
                $(this).hide();
            } else {
                $(this).show();
            }
        });

        Features.repaintFriendsInvitations();
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
    },

    addAttempts: function (delta) {
        Api.addAttempts(delta, function (data) {
            console.log('add attempts', data);
        });
    },

    getPurchases: function () {
        return [];
    },

    getPurchaseOptionsPresentation: function (options) {
        var html = "";
        var template = $('.purchase-option-template').html();
        $(options).each(function () {
            html += TemplateEngine.parseTemplate(template, this);
        });
        return html;
    },

    loadPurchasesWindow: function () {

        var purchases = this.getPurchases();
        console.log(purchases);
        var attemptsHtml = this.getPurchaseOptionsPresentation(purchases.attempts);
        var hintsHtml = this.getPurchaseOptionsPresentation(purchases.attempts);

        $('.hint-options').html(hintsHtml);
        $('.attempt-options').html(attemptsHtml);
    }
};

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
        $.getScript(document.location.protocol + "//vk.com/js/api/xd_connection.js?2", function () {
            VKFeatures.initFields(function () {
                Api.initialRequest(function (data) {
                    Features.user = data.user;
//                    Features.user.allAttempts = 0;

                    for (var key in data.results) {
                        $.each(data.results[key], function (i, v) {
                            console.log(i, v);
                            var user_obj = Features.getUserObject(+key.replace("u", ""));
                            Features.chapters[v.chapterId] = Features.chapters[v.chapterId] || {};
                            Features.chapters[v.chapterId][v.levelId] = Features.chapters[v.chapterId][v.levelId] || {};
                            Features.chapters[v.chapterId][v.levelId][key] = $.extend(user_obj, {
                                'dynamic': +v.numDynamic,
                                'static': +v.numStatic,
                                'result': +v.result,
                                'time': +v.time
                            }, true);
                        });
                    }

                    //

                    var friends_in_game = [];

                    for (var key in data) {
                        friends_in_game.push(
                            extendAndOverride(
                                {id: +key.substr(1), result: Features.calcResult(data[key])},
                                Features.getUserObject(+key.substr(1)))
                        );
                    }

                    // Descending sort by stars amount
                    friends_in_game.sort(function (a, b) {
                        return a.result === b.result
                            ? 0
                            : (a.result > b.result ? -1 : 1);
                    });

                    Features.friends_in_game = friends_in_game;
                });

                callback();
            });
        });
    },

    getPurchases: function () {
        return {
            hints: [
                {
                    name: "1 hint",
                    price: "4 votes",
                    data: "h.1."
                },
                {
                    name: "2 hints",
                    price: "8 votes",
                    data: "h.5."
                },
                {
                    name: "5 hints",
                    price: "16 votes",
                    data: "h.10."
                },
                {
                    name: "10 hints",
                    price: "24 votes",
                    data: "h.25."
                }
            ],
            attempts: [
                {
                    name: "+10 attempts",
                    price: "2 votes",
                    data: "a.10."
                },
                {
                    name: "+25 attempts",
                    price: "4 votes",
                    data: "a.25."
                },
                {
                    name: "+50 attempts",
                    price: "8 votes",
                    data: "a.50."
                },
                {
                    name: "+100 attempts",
                    price: "12 votes",
                    data: "a.100."
                }
            ],
            chapters: [
                {
                    stars: 0.5,
                    price: "100 votes",
                    data: "c.5."
                },
                {
                    stars: 0.33,
                    price: "50 votes",
                    data: "c.3."
                },
                {
                    stars: 0.2,
                    price: "30 votes",
                    data: "c.2."
                },
                {
                    stars: 0,
                    price: "10 votes",
                    data: "c.0."
                }
            ]
        }
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
        this.initFields(callback);
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
        //console.log('loaded!');
    });

    //setInterval(Features.keepAlive, 5000);
})();