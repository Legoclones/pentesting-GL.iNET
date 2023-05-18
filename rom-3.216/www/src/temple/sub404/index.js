"use strict";

define(["text!temple/sub404/index.html", "vue"], function (stpl, Vue) {
    var vueComponent = Vue.extend({
        template: stpl,
    });
    return vueComponent;
});