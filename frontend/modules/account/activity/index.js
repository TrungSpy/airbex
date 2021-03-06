var moment = require('moment')
, _ = require('lodash')
,  itemTemplate = require('./item.html')
, template = require('./index.html')

module.exports = function() {
    var $el = $('<div class=account-activity>').html(template())
    , controller = {
        $el: $el
    }
    , $items = controller.$el.find('.activities')

    function itemsChanged(items) {
        // Filter out admin items
        items = _.filter(items, function(item) {
            return !item.type.match(/^Admin/)
        })

        // Sort so that fills appear after creates
        items = _.sortBy(items, function(item) {
            var epoch = moment(item.created).unix()

            if (item.type == 'FillOrder') {
                epoch += 5
            }

            return -epoch
        })

        $items.html($.map(items, function(item) {
            var duration = new Date() > moment(item.created) ?
                moment(item.created).fromNow() : moment().fromNow()

            item.ago = duration
            item.text = require('../../../helpers/activity')(item)
            if(item.text){
                return itemTemplate(item)
            }
        }))
    }

    function refresh() {
        api.call('v1/activities')
        .then(itemsChanged)
        .fail(errors.alertFromXhr)
    }

    refresh()

    return controller
}
