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

var getRandomInRange = function (floor, ceil, not) {
    var rand = Math.floor(Math.random() * (1 + ceil - floor)) + floor;
    return not != undefined ? (rand === not ? getRandomInRange(floor, ceil, not) : rand) : rand;
};

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
    var diff = 0;

    if (a.result === b.result) {
        if (a.dynamic != undefined && b.dynamic != undefined) {
            if (a.dynamic == b.dynamic) {
                if (a.static != undefined && b.static != undefined) {
                    if (a.static !== b.static) {
                        diff = a.static > b.static ? -1 : 1;
                    }
                }
            } else {
                diff = a.dynamic > b.dynamic ? -1 : 1;
            }
        }
    } else {
        diff = a.result > b.result ? -1 : 1;
    }

    return diff;
};

var imageLoaded = function (img) {
    if (!img.complete) {
        return false;
    }

    if (typeof img.naturalWidth !== "undefined" && img.naturalWidth === 0) {
        return false;
    }

    return true;
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
    platformUser: {
        first_name: '',
        last_name: '',
        photo: ''
    },
    user: {},
    chapters: {},
    results_by_chapters: {},
    friends_in_game: [],
    friends: [],
    orderListener: null,

    setOnLoadedCallback: function (callback) {
        this.onLoaded = callback;

        if (this.initialized) {
            callback();
        }
    },

    getFinishedUsersAsSortedArray: function (obj) {
        var users = [];

        $.each(obj, function (k, v) {
            users.push($.extend(v, {
                id: k.replace("u", "")
            }));
        });

        users.sort(user_sort);

        return users;
    },

    showFinishedFriends: function (chapter, level, callback) {
        $('.finished-friends').empty();

        var users = Features.getFinishedUsersAsSortedArray(Features.chapters[chapter][level]);
        var counter = 0;

        $(users).each(function () {
            $('.friends-ribbon').append(TemplateEngine.parseTemplate($('.finished-friend-template').html(), $.extend(this, {
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

    onLevelFinish: function (chapter, level, result, numDynamic, numStatic, attempts, timeSpent) {
        Api.finishLevel(chapter, level, result, numDynamic, numStatic, attempts, timeSpent, function (data) {
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
    },

    resetSharing: function () {
        $('.share-level').removeClass('share-succeeded').removeAttr('disabled').html(locale.share_result);
    },

    startSharing: function () {
        $('.share-level').addClass('share-succeeded').attr('disabled', 'disabled').html(locale.sharing_process);
    },

    failSharing: function () {
        Features.resetSharing();
    },

    successSharing: function () {
        $('.share-level').addClass('share-succeeded').html(locale.shared);
    },

    //

    resetGameSharing: function () {
        $('.share-offer').removeClass('share-succeeded').removeAttr('disabled').html(locale.share_offer);
    },

    startGameSharing: function () {
        $('.share-offer').addClass('share-succeeded').attr('disabled', 'disabled').html(locale.sharing_process);
    },

    failGameSharing: function () {
        Features.resetGameSharing();
    },

    successGameSharing: function () {
        $('.share-offer').addClass('share-succeeded').html(locale.shared);
    },

    // Social sharing existed only for the removed VK/Facebook integrations.
    // The compiled Dart still calls these from (hidden) share buttons, so
    // keep them as no-ops.
    shareWithFriends: function (callback) {
    },

    prepareLevelWallPost: function (level_name, stars_html, chapter, level, result, _dynamic, _static) {
        return '';
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
        this.user.allAttempts = 125;
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

    Features = extendAndOverride(Features, NoFeatures);

    Features.tutorial_img = new Image();
    Features.tutorial_img.src = 'img/tutorial/tutorial_' + qs['app_lang'] + '.gif';

    // The locale is boot-critical (Features.load runs from its callback), so
    // retry: a dropped subresource (e.g. Cloudflare+Firefox HTTP/3 failures)
    // must not leave the game stuck on the loading screen.
    var getLocale = function (attempt) {
        $.getScript('external/locales/' + qs['app_lang'] + '.js', onLocaleLoaded).fail(function () {
            if (attempt >= 6) return;
            setTimeout(function () {
                getLocale(attempt + 1);
            }, 100 * attempt);
        });
    };

    var onLocaleLoaded = function () {
        $('.localized').each(function () {
            var postfix = '';
            if ($(this).hasClass('mac-dependant')) {
                postfix = '_mac';
            }

            var t = locale[$(this).data('lid') + postfix];
            if (t) {
                $(this).html(t);
            }
        });

        $('.localized-title').each(function () {
            var postfix = '';
            if ($(this).hasClass('mac-dependant')) {
                postfix = '_mac';
            }

            var t = locale[$(this).data('tlid') + postfix];
            if (t) {
                $(this).attr('title', t);
            }
        });

        Features.load(function () {
            Features.initialized = true;
            Features.onLoaded();
        });
    };

    getLocale(1);
})();