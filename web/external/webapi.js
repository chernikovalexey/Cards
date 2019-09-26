function WebApi(method, data, callback, async) {
    var json = JSON.stringify(data);

    var url = "/serverside/index.php";
    $.ajax({
        type: 'POST',
        url: url,
        async: async == undefined ? true : async,
        data: {arguments: json, method: method},
        success: function (r) {
            callback(r);
        }
    });
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