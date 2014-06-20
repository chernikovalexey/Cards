/**
 * Created by podko_000 on 05.06.14.
 */

function WebApi(method, data, callback) {
    var json = JSON.stringify(data);
    $.ajax({
        type: 'POST',
        url: "/Cards/serverside/index.php",
        data: {arguments: json, method: method},
        success: callback
    });
}

var Api = {
  platform: "nil",
  friendsList: null,
  personalId: null,
  setPlatform: function(platform) {
      this.platform = platform;
  },
  setFriendsList: function(listOfFriends) {
      this.friendsList = listOfFriends;
  },
  setPersonalId: function(personalId) {
      this.personalId = personalId;
  },
  initialRequest: function(callback) {
    WebApi(this.platform+".initialRequest", {userId: this.personalId, friends: this.friendsList}, function(data) {
          callback(data);
      });
  },
  finishLevel: function(chapter, level, result, attempts, timeSpent, callback) {
      WebApi(this.platform+".finishLevel", {
          userId: this.personalId,
          chapter: chapter,
          level: level,
          result: result,
          attempts: attempts,
          timeSpent: timeSpent
      }, callback);
  },
  keepAlive: function() {
      WebApi(this.platform+".keepAlive", {
          userId: this.personalId
      });
  }

};