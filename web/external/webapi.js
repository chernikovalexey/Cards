/**
 * Created by podko_000 on 05.06.14.
 */

function WebApi(method, data, callback) {
    var json = JSON.stringify(data);
    $.ajax({
        type: 'POST',
        url: "http://podkolzzzin.org/Cards/serverside?method="+method,
        data: {arguments: json_message},
        method: "POST",
        success: callback
    });
}

