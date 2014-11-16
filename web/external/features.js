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

var getObjectLength = function (obj) {
    var len = 0;
    for (var key in obj) {
        ++len
    }
    return len;
};

var getNumberAsWord = function (num) {
    var words = {
        1: "one", 2: "two", 3: "three", 4: "four", 5: "five", 6: "six"
    };
    return num in words ? words[num] : num;
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
    results_by_chapters: {},
    friends_in_game: [],
    orderListener: null,

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

                var levels_amount = Features.results_by_chapters[this.id]
                    ? Features.results_by_chapters[this.id].levels
                    : 0;
                var chapters_amount = Features.results_by_chapters[this.id]
                    ? Features.results_by_chapters[this.id].chapters
                    : 0;

                $('.card-users').append(TemplateEngine.parseTemplate($('.friend-card-template').html(), $.extend(this, {
                    pos: counter,
                    levels_amount: getNumberAsWord(levels_amount),
                    chapters_amount: getNumberAsWord(chapters_amount),
                    level_ending: levels_amount === 1 ? '' : 's',
                    chapter_ending: chapters_amount === 1 ? '' : 's'
                })));
            });

            callback();
        }
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

    getUser: function (callback) {
        Api.call("getUser", {}, function (result) {
            Features.user = result;
            callback();
        });
    },

    getPurchaseOptionsPresentation: function (options) {
        var html = "";
        var template = $('.purchase-option-template').html();
        $(options).each(function () {
            html += TemplateEngine.parseTemplate(template, this);
        });
        return html;
    },

    makePurchase: function () {

    },

    loadPurchasesWindow: function () {

        var purchases = this.getPurchases();
        console.log(purchases);
        var attemptsHtml = this.getPurchaseOptionsPresentation(purchases.attempts);
        var hintsHtml = this.getPurchaseOptionsPresentation(purchases.hints);

        $('.hint-options').html(hintsHtml);
        $('.attempt-options').html(attemptsHtml);

        $('.purchase-option').click(this.makePurchase);
    },

    unlockChapter: function () {
    },

    chapterCallback: null,

    getChapters: function (callback) {
        this.chapterCallback = callback;
        Api.call('chapters', {}, function (r) {
            Features.chapterCallback(JSON.stringify(r));
        });
    },

    scrollParentTop: function () {
    }
};

var VKFeatures = {
    friends: null,

    scrollParentTop: function () {
    },

    prepareLevelWallPost: function (level_name, stars) {
        var upload = function (permission) {
            if (!(permission & 4)) {
                return false;
            } else {
                VK.api('photos.getWallUploadServer', {}, function (data) {
                    if (data.response) {
                        var upload_url = data.response.upload_url;

                        // Prepare photo
                        html2canvas($('.level-wall-post-template').get(0), {
                            onrendered: function (canvas) {
                                console.log(canvas.toDataURL());
                                Api.call("uploadPhoto", {server: upload_url, base64image: canvas.toDataURL().replace("data:image/png;base64,", "")}, function (upload_response) {
                                    console.log(upload_response);
                                    VK.api("photos.saveWallPhoto", {
                                        user_id: Features.user.platformUserId,
                                        photo: upload_response.photo,
                                        server: upload_response.server,
                                        hash: upload_response.hash
                                    }, function (save_response) {
                                        console.log(save_response);
                                        VK.api("wall.post", {
                                            message: "Пацаны, я, кароче, очень крутой. Зацените!",
                                            attachments: save_response.response[0].id
                                        });
                                    });
                                });
                            }
                        });
                    }
                });
                return true;
            }
        };

        VK.api('account.getAppPermissions', function (r) {
            if (!upload(r.response)) {
                VK.callMethod("showSettingsBox", 4);
                VK.addCallback("onSettingsChanged", upload);
            }
        });
    },

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

    unlockChapter: function (chapter) {
        VK.callMethod("showOrderBox", {
            type: 'item',
            item: 'c.' + chapter + '.' + this.user.platformUserId
        });
    },

    load: function (callback) {
        $.getScript(document.location.protocol + "//vk.com/js/api/xd_connection.js?2", function () {
            VKFeatures.initFields(function () {
                Api.initialRequest(function (data) {
                    Features.user = data.user;
//                    Features.user.allAttempts = 0;

                    var results_by_chapters = {};

                    for (var key in data.results) {
                        $.each(data.results[key], function (i, v) {
                            var user_id = +key.replace("u", "");
                            var user_obj = Features.getUserObject(user_id);
                            results_by_chapters[user_id] = results_by_chapters[user_id] || {};
                            results_by_chapters[user_id][v.chapterId] = (results_by_chapters[user_id][v.chapterId] || 0) + 1;
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

                    for (var user in results_by_chapters) {
                        var levels = 0;
                        for (var chapter in results_by_chapters[user]) {
                            levels += results_by_chapters[user][chapter];
                        }

                        Features.results_by_chapters[user] = {
                            levels: levels,
                            chapters: getObjectLength(results_by_chapters[user])
                        };
                    }

                    delete results_by_chapters;

                    //

                    var friends_in_game = [];

                    for (var key in data.results) {
                        friends_in_game.push(
                            extendAndOverride(
                                {id: +key.substr(1), result: Features.calcResult(data.results[key])},
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
                VK.addCallback('onOrderSuccess', Features.onOrderSuccess);
                callback();
            });
        });
    },

    appendUserId: function (data) {
        $(data).each(function () {
            this.data += Features.user.platformUserId;
        })
    },

    getPurchases: function () {
        var data = {
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
        this.appendUserId(data.attempts);
        this.appendUserId(data.hints);
        this.appendUserId(data.chapters);
        return data;
    },

    makePurchase: function () {
        VK.callMethod("showOrderBox", {
            type: 'item',
            item: $(this).data('item')
        });
    },

    onOrderSuccess: function () {
        console.log("JS order success!");
        if (Features.orderListener != null) {
            console.log("callback!=null");
            Features.orderListener();
        }
    },

    chapterCallback: null,

    chapters: function (callback) {
        this.chapterCallback = callback;
        Api.call('chapters', {}, function (r) {
            Features.chapterCallback(JSON.stringify(r));
        });
    },

    showInviteBox: function () {
        VK.callMethod("showInviteBox");
    }
};

var FBFeatures = {
    initFields: function (callback) {
        FB.api("/me/friends", function (response) {
            console.log("Friends:", response);
            Api.setFriendsList(Features.toIdArray(response.data));
            Features.friends = response.data;

            Api.setPersonalId(response.id);
            Api.setPlatform('fb');

            callback();
        });
    },

    load: function (callback) {
        $.getScript("//connect.facebook.net/en_US/sdk.js", function () {
            FB.init({
                appId: 614090422033888,
                status: true,
                cookie: true,
                xfbml: false,
                version: 'v2.1'
            });

            FB.login(function () {
                Features.initFields(function () {
                    Api.initialRequest(function (data) {
                        console.log("initial request:", data);

                        callback();
                    });
                });
            });
        });
    },

    showInviteBox: function () {
        FB.ui({method: 'apprequests',
            message: 'Check out this new puzzle!'
        }, function (response) {
            console.log(response);
        });
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
        case 'fb':
            Features = extendAndOverride(Features, FBFeatures);
            break;
        default:
            Features = extendAndOverride(Features, NoFeatures);
    }

    Features.load(function () {
        //console.log('loaded!');
    });

    //setInterval(Features.keepAlive, 5000);
})();