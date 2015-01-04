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

if (typeof String.prototype.endsWith !== 'function') {
    String.prototype.endsWith = function (suffix) {
        return this.indexOf(suffix, this.length - suffix.length) !== -1;
    };
}

if (!String.prototype.format) {
    String.prototype.format = function () {
        var args = arguments;
        return this.replace(/{(\d+)}/g, function (match, number) {
            return typeof args[number] != 'undefined'
                ? args[number]
                : match
                ;
        });
    };
}

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
    return num in locale ? locale[num] : num;
};

var user_sort = function (a, b) {
    return a.result === b.result
        ? 0
        : (a.result > b.result ? -1 : 1);
};

var Features = {
    getNounPlural: function (num, form1, form2, form3) {
        var ending;

        num %= 100;
        if (num >= 11 && num <= 19) {
            ending = form1;
        } else {
            switch (num % 10) {
                case 1:
                    ending = form2;
                    break;
                case 2:
                case 3:
                case 4:
                    ending = form3;
                    break;
                default:
                    ending = form1;
            }
        }
        return ending;
    },

    hideLoading: function () {
        Features.updateLoadingBar(100, function () {
            $(".game-box").removeClass("blurred");
            $(".loading-overlay").fadeOut(275, 'easeOutQuart', function () {
                $(this).remove();
            });
        });
    },

    updateLoadingBar: function (percentage, callback) {
        $('.running-bar').animate({width: 600 * percentage / 100}, 150, 'easeOutQuart', callback || function () {
        });
    },

    keepAlive: function () {
        Api.keepAlive();
    },

    onOrderSuccess: function () {
        console.log("JS order success!");
        if (Features.orderListener != null) {
            console.log("callback!=null");
            Features.orderListener();
        }
    },

    repaintFriendsInvitations: function () {
        $('#invitations-scroll').empty();
        var scroll = new dw_scrollObj('invitations-vs', 'invitations-es');
        scroll.buildScrollControls('invitations-scrollbar', 'v', 'mouseover', true);
    },

    tutorial_img: null,
    is_macintosh: false,
    initialized: false,
    onLoaded: function () {
    },
    user: {},
    chapters: {},
    results_by_chapters: {},
    friends_in_game: [],
    orderListener: null,

    setOnLoadedCallback: function (callback) {
        this.onLoaded = callback;

        if (this.initialized) {
            callback();
        }
    },

    showFinishedFriends: function (chapter, level, callback) {
        var users = [];

        $('.finished-friends').empty();

        $.each(Features.chapters[chapter][level], function (k, v) {
            users.push($.extend(v, {
                id: k.replace("u", "")
            }));
        });

        users.sort(user_sort);

        var counter = 0;
        $(users).each(function () {
            $('.finished-friends').append(TemplateEngine.parseTemplate($('.finished-friend-template').html(), $.extend(this, {
                pos: ++counter
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

                var obj = $.extend(this, {
                    pos: counter,
                    completed: Features.getNounPlural(levels_amount, locale.completed_form1, locale.completed_form2, locale.completed_form3),
                    levels_amount: getNumberAsWord(levels_amount),
                    chapters_amount: locale[chapters_amount + 'd'] ? locale[chapters_amount + 'd'] : chapters_amount,
                    level_ending: Features.getNounPlural(levels_amount, locale.level_form1, locale.level_form2, locale.level_form3),
                    chapter_ending: Features.getNounPlural(chapters_amount, locale.chapterd_form1, locale.chapterd_form2, locale.chapterd_form3)
                });
                $('.card-users').append(TemplateEngine.parseTemplate($('.friend-card-template').html(), obj));

                if (chapters_amount === 0) {
                    $('.fr-pos-' + obj.pos).find('.fr-succeeded').html(locale.not_played);
                }
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

    getPurchaseOptionsPresentation: function (options, unlimited, text) {
        var html = "";

        if (unlimited) {
            html = text;
        } else {
            var template = $('.purchase-option-template').html();
            $(options).each(function () {
                html += TemplateEngine.parseTemplate(template, this);
            });
        }

        return html;
    },

    makePurchase: function () {
    },

    loadPurchasesWindow: function () {
        var purchases = this.getPurchases();
        var attemptsHtml = this.getPurchaseOptionsPresentation(purchases.attempts, Features.user.boughtAttempts === -1, '<div class="unlimited-attempts">' + locale['unlimited_attempts'] + '</div>');
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

    shareWithFriends: function () {
        var upload = function (permission) {
            if (!(permission & 4)) {
                return false;
            } else {
                VK.api('photos.getWallUploadServer', {}, function (data) {
                    if (data.response) {
                        Api.call("uploadPhotoReserved", {server: data.response.upload_url, photo: "promo"}, function (upload_response) {
                            console.log('upload resp', upload_response);
                            VK.api("photos.saveWallPhoto", {
                                user_id: Features.user.platformUserId,
                                photo: upload_response.photo,
                                server: upload_response.server,
                                hash: upload_response.hash
                            }, function (save_response) {
                                console.log('save resp', save_response);
                                VK.api("wall.post", {
                                    message: "Пацаны, давайте поиграем в Два Куба ))",
                                    attachments: save_response.response[0].id + ",https://vk.com/twocubes"
                                });
                            });
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

    prepareLevelWallPost: function (level_name, stars_html) {
        var upload = function (permission) {
            if (!(permission & 4)) {
                return false;
            } else {
                VK.api('photos.getWallUploadServer', {}, function (data) {
                    if (data.response) {
                        var upload_url = data.response.upload_url;

                        $('.level-wall-post-template').find('.s-level-name').html(level_name);
                        $('.level-wall-post-template').find('.level-rating').html(stars_html);

                        html2canvas($('.level-wall-post-template').get(0), {
                            onrendered: function (canvas) {
                                Api.call("uploadPhoto", {server: upload_url, photo: canvas.toDataURL().replace("data:image/png;base64,", "")}, function (upload_response) {
                                    console.log(upload_response);
                                    VK.api("photos.saveWallPhoto", {
                                        user_id: Features.user.platformUserId,
                                        photo: upload_response.photo,
                                        server: upload_response.server,
                                        hash: upload_response.hash
                                    }, function (save_response) {
                                        VK.api("wall.post", {
                                            message: "I've completed level " + level_name + " in Two Cubes!/n#twocubes",
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

            Features.initialized = true;

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
        Features.updateLoadingBar(15);

        $.getScript(document.location.protocol + "//vk.com/js/api/xd_connection.js?2", function () {
            Features.updateLoadingBar(55);

            VKFeatures.initFields(function () {
                Features.updateLoadingBar(70);
                Api.auth_key = qs['auth_key'];
                Api.initialRequest(function (data) {
                    if (data.error === true) {
                        document.body.innerHTML = JSON.stringify(data);
                        alert(data.message);
                        return;
                    }
                    Features.updateLoadingBar(85);

                    console.log("initial request vk:", data);
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

                    Features.updateLoadingBar(95);

                    callback();
                });
            });

            VK.addCallback('onOrderSuccess', Features.onOrderSuccess);
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
                    name: "1 " + locale.hint_form2,
                    price: "4 " + locale.vote_form3,
                    data: "h.1."
                },
                {
                    name: "2 " + locale.hint_form3,
                    price: "8 " + locale.vote_form1,
                    data: "h.5."
                },
                {
                    name: "5 " + locale.hint_form1,
                    price: "16 " + locale.vote_form1,
                    data: "h.10."
                },
                {
                    name: "10 " + locale.hint_form1,
                    price: "24 " + locale.vote_form3,
                    data: "h.25."
                }
            ],
            attempts: [
                {
                    name: "10 " + locale.attempt_form1,
                    price: "2 " + locale.vote_form3,
                    data: "a.10."
                },
                {
                    name: "25 " + locale.attempt_form1,
                    price: "4 " + locale.vote_form3,
                    data: "a.25."
                },
                {
                    name: "50 " + locale.attempt_form1,
                    price: "8 " + locale.vote_form1,
                    data: "a.50."
                },
                {
                    name: "100 " + locale.attempt_form1,
                    price: "12 " + locale.vote_form1,
                    data: "a.100."
                },
                {
                    is_infinity: true,
                    name: "∞ " + locale.attempt_form1,
                    price: "80 " + locale.vote_form1,
                    data: "a.-1."
                }
            ],
            chapters: [
                {
                    stars: 0.5,
                    price: "100 " + locale.vote_form1,
                    data: "c.5."
                },
                {
                    stars: 0.33,
                    price: "50 " + locale.vote_form1,
                    data: "c.3."
                },
                {
                    stars: 0.2,
                    price: "30 " + locale.vote_form1,
                    data: "c.2."
                },
                {
                    stars: 0,
                    price: "10 " + locale.vote_form1,
                    data: "c.0."
                }
            ]
        };

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

    chapterCallback: null,

    showInviteBox: function () {
        VK.callMethod("showInviteBox");
    }
};

var FBFeatures = {
    initFields: function (callback) {
        FB.api("/me", function (me_res) {
            FB.api("me/friends?fields=last_name,first_name,picture", function (fr_res) {
                console.log("Friends:", fr_res);
                Api.setFriendsList(Features.toIdArray(fr_res.data));
                Features.friends = fr_res.data;

                Api.setPersonalId(me_res.id);
                Api.setPlatform('fb');

                callback();
            });
        });
    },

    unlockChapter: function (chapter) {
        var data = encodeURIComponent(JSON.stringify({
            'userId': this.user.platformUserId,
            'chapter': chapter
        }));

        FB.ui({
            method: 'pay',
            action: 'purchaseitem',
            product: 'http://twopeoplesoftware.com/twocubes28340jfddv03jfd/serverside/index.php?method=fb.fbGetChapterUnlockOg&arguments=' + data
        }, function (r) {
            if (r.status == "initiated" || r.status == "completed") {
                Features.onOrderSuccess();
            }
        });
    },

    toUserObject: function (fr) {
        console.log('trying to get user object:', fr);
        return {
            id: fr.id,
            name: fr.first_name,
            surname: fr.last_name,
            ava: fr.picture.data.url
        };
    },

    getUserObject: function (id) {
        for (var i = 0; i < this.friends.length; i++) {
            var fr = this.friends[i];
            if (fr.id == id) {
                return this.toUserObject(fr);
            }
        }
    },

    load: function (callback) {
        Features.updateLoadingBar(15);

        $.getScript("//connect.facebook.net/en_US/sdk.js", function () {
            Features.updateLoadingBar(25);

            FB.init({
                appId: 614090422033888,
                status: true,
                cookie: true,
                xfbml: false,
                version: 'v2.1'
            });

            FB.login(function () {
                Features.updateLoadingBar(40);

                Features.initFields(function () {
                    Features.updateLoadingBar(60);

                    Api.initialRequest(function (data) {
                        Features.updateLoadingBar(80);

                        Features.user = data.user;

                        console.log('initial request fb:', data);

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
                        friends_in_game.sort(user_sort);

                        Features.friends_in_game = friends_in_game;

                        Features.updateLoadingBar(95);

                        callback();
                    });
                });
            }, {scope: 'user_about_me, user_friends'});
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
                    price: "0.5$",
                    data: "1-h"
                },
                {
                    name: "2 hints",
                    price: "1$",
                    data: "5-h"
                },
                {
                    name: "5 hints",
                    price: "2$",
                    data: "10-h"
                },
                {
                    name: "10 hints",
                    price: "3$",
                    data: "25-h"
                }
            ],
            attempts: [
                {
                    name: "+10 attempts",
                    price: "0.25$",
                    data: "10-a"
                },
                {
                    name: "+25 attempts",
                    price: "0.5$",
                    data: "25-a"
                },
                {
                    name: "+50 attempts",
                    price: "1$",
                    data: "50-a"
                },
                {
                    name: "+100 attempts",
                    price: "3$",
                    data: "100-a"
                }
            ],
            chapters: [
                {
                    stars: 0.5,
                    price: "100 votes",
                    data: "5-c"
                },
                {
                    stars: 0.33,
                    price: "50 votes",
                    data: "3-c"
                },
                {
                    stars: 0.2,
                    price: "30 votes",
                    data: "2-c"
                },
                {
                    stars: 0,
                    price: "10 votes",
                    data: "0-c"
                }
            ]
        }

        return data;
    },

    makePurchase: function () {
        var item = $(this).data('item');
        console.log(item);
        FB.ui({
            method: 'pay',
            action: 'purchaseitem',
            product: 'https://twopeoplesoftware.com/twocubes28340jfddv03jfd/fb_payments/' + item + '.html'
        }, function (r) {
            if (r.status == "initiated" || r.status == "completed") {
                Features.onOrderSuccess();
            }
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
    if (navigator.appVersion.indexOf("Mac") != -1) {
        Features.is_macintosh = true;
    }

    qs['app_lang'] = 'en';

    switch (qs['platform']) {
        case 'vk':
            Features = extendAndOverride(Features, VKFeatures);

            if (+qs['language'] in {0: 0, 1: 0, 777: 0, 100: 0}) {
                qs['app_lang'] = 'ru';
            }
            break;
        case 'fb':
            Features = extendAndOverride(Features, FBFeatures);
            break;
        default:
            Features = extendAndOverride(Features, NoFeatures);
    }

    Features.tutorial_img = new Image();
    Features.tutorial_img.src = 'img/tutorial/tutorial_' + qs['app_lang'] + '.gif';

    $.getScript('external/locales/' + qs['app_lang'] + '.js', function () {
        $('.localized').each(function () {
            var t = locale[$(this).data('lid')];
            if (t) {
                $(this).html(t);
            }
        });

        $('.localized-title').each(function () {
            var t = locale[$(this).data('lid')];
            if (t) {
                $(this).attr('title', t);
            }
        });

        Features.load(function () {
            Features.initialized = true;
            Features.onLoaded();
        });
    });
})();