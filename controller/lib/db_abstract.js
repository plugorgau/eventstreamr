var events = require('events');
var feed = new events.EventEmitter();
var request = require('request')

// datastore connection
var Datastore = require('nedb')
  , db = {
    stations: new Datastore({ filename: 'storage/stations.db' , autoload: true}),
    rooms: new Datastore({ filename: 'storage/rooms.db' , autoload: true})
  }

var callback = function(error, success) {
  if (err) callback(err)
  if (success) {
    callback(null, success)
  }
}

exports.insert = function(table, document, callback) {
  db[table].insert(document, function (error, success) {
    if (error) callback(err)
    if (success) {
      feed.emit('change', {type: 'insert', content: success})
      callback(null, success)
    }
  })
}

exports.remove = function(table, query, callback) {
  db[table].findOne(query, function(error, original) {
    var id = original._id
    db[table].remove(query, {}, function(error, success) {
      if (error) callback(err)
      if (success) {
        feed.emit('change', {type: 'remove', content: id})
        callback(null, success)
      }
    })
  })
}

exports.update = function(table, query, partial, callback)  {
  db[table].update(query, { $set: partial }, {}, function(error, success) {
    if (error) {
      console.log(error)
      callback(error)
    }
    if (success) {
      db[table].findOne(query, function(error, original) {
        feed.emit('change', {type: 'update', content: original})
        callback(null, original)
      })
    }
  })
}

exports.updateRaw = function(table, query, partial, callback) {
  db[table].update(query, partial, {}, function(error, success) {
    if (error) callback(err)
    if (success) {
      db[table].findOne(query, function(error, original) {
        feed.emit('change', {type: 'update', content: original})
      })
      callback(null, success)
    }
  })
}

exports.get = function(table, query, callback) {
  db[table].findOne(query, callback)
}

exports.list = function(table, query, callback) {
  db[table].find(query, callback)
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
