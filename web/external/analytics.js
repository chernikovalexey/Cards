/**
 * Created by podko_000 on 20.05.14.
 */





function Analytics() {
    this.sessionId = null;
}

Analytics.prototype.extendAndOverride = function (o1, o2) {
    for (var key in o2) {
        o1[key] = o2[key];
    }
    return o1;
};

Analytics.prototype.send = function(message) {
    var game_key = '2adf5d6837a8a8b744a94772176f654d';
    var secret_key = 'fe9befdac51d6ce91a6b62bed933e59751078c47';
    var category = "design";

    var basic = {
        user_id: this.getUserId(),
        session_id: this.sessionId,
        build: "AnalyticsTest"
    };

    message = this.extendAndOverride(message, basic);

    var url = 'http://api-eu.gameanalytics.com/1/'+game_key+'/'+category;

    var json_message = JSON.stringify(message);
    var md5_msg = CryptoJS.MD5(json_message + secret_key);
    var header_auth_hex = CryptoJS.enc.Hex.stringify(md5_msg);
    $.ajax({
        type: 'POST',
        url: url,
        data: json_message,
        headers: {
            "Authorization": header_auth_hex
        },
        beforeSend: function (xhr) {
            xhr.setRequestHeader('Content-Type', 'text/plain');
        },
        success: function(data, textStatus, XMLHttpRequest) {
            console.log("GOOD! textStatus: " + textStatus);
        },
        error: function(XMLHttpRequest, textStatus, errorThrown) {
            console.log("ERROR ajax call. error: " + errorThrown + ", url: " + url);
        }
    });
};

Analytics.prototype.sendLevelEvent = function(type, chapter, level, data) {
    var obj = {
        event_id: type,
        chapter: chapter,
        level: level
    };
    if(data!=null)
        obj = this.extendAndOverride(obj, data);
    this.send(obj);
};

Analytics.prototype.getStamp = function() {
    var dt = new Date();
    return "" + dt.getMilliseconds() + dt.getTime();
};

Analytics.prototype.setUserId = function() {
    return window.localStorage['user_id'] = this.getStamp();
};

Analytics.prototype.getUserId = function() {
    return (window.localStorage['user_id']!=null)?window.localStorage['user_id']:this.setUserId();
};


Analytics.prototype.startSession = function() {
    this.sessionId = this.getStamp() + "." + this.getUserId();
    this.send({
        event_id: "Session:Start"
    });
};

Analytics.prototype.applyPhysics = function(chapter, level) {
    this.sendLevelEvent("Level:ApplyPhysics", chapter, level);
};

Analytics.prototype.rewindPhysics = function(chapter, level) {
    this.sendLevelEvent("Level:RewindPhysics", chapter, level);
};

Analytics.prototype.levelComplete = function(chapter, level, nStatic, nDynamic, stars, time) {
    this.sendLevelEvent("Level:Complete", chapter, level, {
        "static": nStatic,
        dynamic: nDynamic,
        stars: stars,
        timeSpent: time
    });
};

