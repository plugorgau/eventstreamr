var db = require('../lib/db_abstract')

var removeIp = function(ip) {
  db.updateRaw('stations', { ip: ip }, { $unset: { ip: true } }, {}, function () {});
}

var updateIp = function(mac, ip) {
  db.updateRaw('stations', { "setings.mac": mac }, { $set: { ip: ip } }, {}, function () {});
}

var Station = function(request) {
  var macaddress = (request.macaddress) ? request.macaddress.replace(/:\s*/g, "-") : null;
  if (request.roles && typeof request.roles == 'string') {
    request.roles = [request.roles]
  }
  return {
    macaddress: macaddress,
    roles: request.roles || [],
    room: request.room,
    nickname: request.nickname
  }
}

var storeStation = function(settings, ip, callback) {
  var document = {
    ip: ip || null,
    settings: settings
  }
  db.insert('stations', document, callback)
}

exports.createStation = function(req, res) {
  var station = new Station(req.body)
  storeStation(station, null, function(error, success) {
    if (error) {
      res.send(500, error)
    }
    if (success) {
      res.send(true)
    }
  })
}

exports.deleteStation = function(req, res) {
  db.remove('stations', {'_id': req.params.mac}, function(error, removed) {
    if (removed) {
      res.send(204, true)
    }
  })
}

var tablesDocLookups = {
  stations: 'settings.mac',
}

var tableNames = Object.keys(tablesDocLookups)

exports.listDb = function(req, res) {
  if (tableNames.indexOf(req.params.db) !== -1) {
    db.list(req.params.db, {}, function (error, docs) {
      if (error) {
        res.send(500, err)
      }
      if (docs) {
        res.send(docs)
      }
    });
  }
  else {
    res.send(404)
  }
}

exports.getDocument = function(req, res) {
  if (tableNames.indexOf(req.params.db) !== -1) {
    var query = {}
    query[tablesDocLookups[req.params.db]] = req.params.id;
    console.log(query)
    db.get(req.params.db, query, function (error, doc) {
      if (error) {
        res.send(500, error)
      }
      if (doc === null) {
        res.send(204)
      }
      if (doc) {
        res.send(200, doc)
      }
    });
  }
  else {
    res.send(404)
  }
}

exports.registerStation = function(req, res) {
  db.get('stations', { 'settings.mac': req.params.mac }, function (error, doc) {
    if (doc === null) {
      var station = new Station({macaddress: req.params.mac})
      storeStation(station, req.ip, function(error, success) {
        if (success) {
          res.send(201)
        }
      })
    }
    if (doc) {
      if (doc.ip !== req.ip) {
        removeIp(req.ip)
        updateIp(req.params.mac, req.ip)
      }
      res.send(200, doc)
    }
  })
}
