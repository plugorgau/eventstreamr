var db = require('../lib/db_abstract')

var removeIp = function(ip) {
  db.updateRaw('stations', { ip: ip }, { $unset: { ip: true } }, {}, function () {});
}

var updateIp = function(mac, ip) {
  db.updateRaw('stations', { "setings.mac": mac }, { $set: { ip: ip } }, {}, function () {});
}

var Station = function(macaddress, roles, room, nickname) {
  macaddress = (macaddress) ? macaddress.replace(/:\s*/g, "-") : null;
  if (roles && typeof roles == 'string') {
    roles = [roles]
  }
  return {
    macaddress: macaddress,
    roles: roles || [],
    room: room || null,
    nickname: nickname || null
  }
}

var storeStation = function(mac, ip, callback) {
  var document = {
    ip: ip || null,
    settings: {"mac" : mac}
  }
  db.insert('stations', document, callback)
}

exports.createStation = function(req, res) {
  var station = new Station(req.body.macaddress, req.body.roles, req.body.room, req.body.nickname)
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

exports.allStations = function(req, res) {
  db.list('stations', {}, function (error, docs) {
    if (error) {
      res.send(500, err)
    }
    if (docs) {
      res.send(docs)
    }
  });
}

exports.getStation = function(req, res) {
  db.get('stations', { 'settings.mac': req.params.mac }, function (error, doc) {
    if (error) {
      res.send(500, error)
    }
    if (doc === null) {
      res.send(204, {
        "status": 'unknown'
      })
    }
    if (doc) {
      res.send(200, doc)
    }
  });
}

exports.registerStation = function(req, res) {
  db.get('stations', { 'settings.mac': req.params.mac }, function (error, doc) {
    if (doc === null) {
      storeStation(req.params.mac, req.ip, function(error, success) {
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
