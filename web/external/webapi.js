// Local, in-browser replacement for the old PHP backend
// (serverside/index.php). The game is fully client-side: progress, stars and
// level state already live in localStorage; the server only ever provided the
// user/attempts object and the chapter list.
//
// Response shapes reproduce the production deploy (twocubes.io, probed
// 2026-07-03) and are pinned by tests/parity.spec.js. Production was
// effectively stateless for the "no" platform (its user INSERT failed
// silently), so these handlers are stateless too.

var LocalServer = {
    chapters: null,

    freshUser: function (data) {
        return {
            userId: 0,
            platformId: 'no',
            platformUserId: String(data.userId),
            isNew: true,
            dayAttempts: 125,
            allAttempts: 125
        };
    },

    totalStars: function () {
        try {
            var stars = JSON.parse(localStorage.getItem('stars'));
            return (stars && typeof stars.total === 'number') ? stars.total : 0;
        } catch (e) {
            return 0;
        }
    },

    loadChapters: function (callback, attempt) {
        if (this.chapters != null) {
            callback(this.chapters);
            return;
        }
        var self = this;
        attempt = attempt || 1;
        // Boot-critical fetch (hideLoading waits on the chapter list) — retry
        // so a dropped subresource can't leave the game on the loading screen.
        $.getJSON('levels/chapters.json', function (json) {
            self.chapters = json.chapters;
            callback(self.chapters);
        }).fail(function () {
            if (attempt >= 6) return;
            setTimeout(function () {
                self.loadChapters(callback, attempt + 1);
            }, 100 * attempt);
        });
    },

    handlers: {
        getUser: function (data, respond) {
            respond(LocalServer.freshUser(data));
        },

        initialRequest: function (data, respond) {
            respond({user: LocalServer.freshUser(data), results: []});
        },

        keepAlive: function (data, respond) {
            respond({result: true});
        },

        finishLevel: function (data, respond) {
            respond({result: true});
        },

        addAttempts: function (data, respond) {
            var delta = data.attemptsUsed != null ? data.attemptsUsed : (data.delta || 0);
            var user = LocalServer.freshUser(data);
            user.dayAttemptsUsed = delta;
            user.dayAttempts = 125 - delta;
            user.allAttempts = 125 - delta;
            respond(user);
        },

        // Production computed "unlocked" from a per-user star total in the
        // database; locally it comes from the same localStorage blob
        // StarManager maintains.
        chapters: function (data, respond) {
            var total = LocalServer.totalStars();
            LocalServer.loadChapters(function (chapters) {
                var r = [];
                $(chapters).each(function () {
                    var c = $.extend({}, this);
                    c.unlocked = c.unlock_stars <= total;
                    r.push(c);
                });
                respond({chapters: r});
            });
        }
    }
};

function WebApi(method, data, callback, async) {
    var name = method.split('.')[1];
    var handler = LocalServer.handlers[name];

    var respond = function (r) {
        if (async === false) {
            callback(r);
        } else {
            setTimeout(function () {
                callback(r);
            }, 0);
        }
    };

    if (handler) {
        handler(data, respond);
    } else {
        // Same idea as the old router's ApiException response.
        respond({error: '404 method not found', method: method, arguments: data});
    }
}

var Api = {
    platform: "nil",
    friendsList: null,
    personalId: null,

    setPlatform: function (platform) {
        this.platform = platform;
    },

    setFriendsList: function (listOfFriends) {
        this.friendsList = listOfFriends;
    },

    setPersonalId: function (personalId) {
        this.personalId = personalId;
    },

    initialRequest: function (callback) {
        WebApi(this.platform + ".initialRequest", {userId: this.personalId, friends: this.friendsList, auth_key: this.auth_key}, function (data) {
            callback(data);
        });
    },

    finishLevel: function (chapter, level, result, numDynamic, numStatic, attempts, timeSpent, callback) {
        WebApi(this.platform + ".finishLevel", {
            userId: this.personalId,
            chapter: chapter,
            level: level,
            result: result,
            numStatic: numStatic,
            numDynamic: numDynamic,
            attempts: attempts,
            timeSpent: timeSpent,
            auth_key: this.auth_key
        }, callback);
    },

    addAttempts: function (delta, callback) {
        WebApi(this.platform + ".addAttempts", {
            auth_key: this.auth_key,
            delta: delta
        }, callback, false);
    },

    keepAlive: function () {
        WebApi(this.platform + ".keepAlive", {
            userId: this.personalId,
            auth_key: this.auth_key
        });
    },

    call: function (method, data, callback, async) {
        data = extendAndOverride({userId: this.personalId, auth_key: this.auth_key}, data || {});
        callback = callback || function (r) {
            console.log(r);
        };
        WebApi(this.platform + "." + method, data, callback, async);
    }
};
