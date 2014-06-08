/**
 * Created by podko_000 on 05.06.14.
 */

function WebApi(method, data, callback) {
    var json = JSON.stringify(data);
    $.ajax({
        type: 'POST',
        url: "http://podkolzin.org/Cards/serverside/index.php",
        data: {arguments: json, method: method},
        success: callback
    });
}

