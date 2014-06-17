/**
 * Created by podko_000 on 17.06.14.
 */

var TemplateEngine = {
    parseHtml: function (h) {
        return h.replace(/&lt;/gi, '<').replace(/&gt;/gi, '>');
    },

    parseTemplate: function (tpl, source) {
        source = source || {};
        tpl = this.parseHtml(tpl);

        for (var key in source) {
            tpl = tpl
                .replace(new RegExp("<%=" + key + "%>", 'g'), source[key])
                .replace(new RegExp("<%= " + key + " %>", 'g'), source[key]);
        }

        return tpl;
    }
}
