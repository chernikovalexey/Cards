function WebApi(method, data, callback) {
    var json = JSON.stringify(data);

    console.log("api request:", data);

    var url = "/twocubes28340jfddv03jfd/serverside/index.php";
    if (document.location.href.indexOf('28340jfddv03jfd') == -1) {
        url = "/twocubes.test/serverside/index.php";
    }

    $.ajax({
        type: 'POST',
        url: url,
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
        WebApi(this.platform + ".initialRequest", {userId: this.personalId, friends: this.friendsList}, function (data) {
            callback(data);
        });
    },

    finishLevel: function (chapter, level, result, numStatic, numDynamic, attempts, timeSpent, callback) {
        WebApi(this.platform + ".finishLevel", {
            userId: this.personalId,
            chapter: chapter,
            level: level,
            result: result,
            numStatic: numStatic,
            numDynamic: numDynamic,
            attempts: attempts,
            timeSpent: timeSpent
        }, callback);
    },

    addAttempts: function (delta, callback) {
        WebApi(this.platform + ".addAttempts", {
            delta: delta
        }, callback);
    },

    keepAlive: function () {
        WebApi(this.platform + ".keepAlive", {
            userId: this.personalId
        });
    },

    call: function (method, data, callback) {
        data = extendAndOverride({userId: this.personalId}, data || {});
        callback = callback || function (r) {
            console.log(r);
        };
        WebApi(this.platform + "." + method, data, callback);
    }
};