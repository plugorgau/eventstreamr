var events = require('events');
var feed = new events.EventEmitter();
var request = require('request');

exports.update = function(doc) {
  console.log("Posting Station Config");
  console.log(doc);
  request.post({
    uri: 'http://' + doc.ip + ':3000/settings/' + doc.settings.macaddress,
    json: doc
  }, function(error) {
    if (error) {
      console.log(error)
      feed.emit('change', {type: 'notify', content: error})
    } else {
      feed.emit('change', {type: 'notify', content: doc})
    }
  })
}

exports.action = function(doc, station) {
  console.log("Posting Station Action");
  console.log(doc);
  request.post({
    uri: 'http://' + station.ip + ':3000/' + doc.command_url + '/' + doc.action,
    json: doc
  }, function(error) {
    if (error) {
      console.log(error)
      feed.emit('change', {type: 'notify', content: error})
    } else {
      feed.emit('change', {type: 'notify', content: doc})
    }
  })
}

feed.on('change', function(info) {
  request.post({
    uri: 'http://localhost:5001/feed',
    json: info
  }, function(error) {
    if (error) {
      console.log(error)
    }
  })
})
