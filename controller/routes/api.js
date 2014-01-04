var db = require('../lib/db_abstract')
var station = require('../lib/station_abstract')

var removeIp = function(ip) {
  db.updateRaw('stations', { ip: ip }, { $unset: { ip: true } }, function () {});
}

var updateIp = function(macaddress, ip) {
  db.updateRaw('stations', { "settings.macaddress": macaddress }, { $set: { ip: ip } }, function () {});
}

var StationSettings = function(request) {
  if (request.roles && typeof request.roles == 'string') {
    request.roles = [request.roles]
  }
  return {
    macaddress: request.macaddress,
    roles: request.roles || [],
    room: request.room || '',
    devices: request.devices || [],
    nickname: request.nickname,
    record_path: request.record_path || null,
    mixer: request.mixer || null,
    stream: request.stream || null,
    sync: request.sync || null,
    run: request.run || 0,
    device_control: request.device_control || null
  }
}

var insertStation = function(settings, ip, callback) {
  var document = {
    ip: ip || null,
    settings: settings
  }
  db.insert('stations', document, callback)
}

exports.registerStation = function(req, res) {
  db.get('stations', { 'settings.macaddress': req.params.macaddress }, function (error, doc) {
    if (doc === null) {
      var station = new StationSettings({macaddress: req.params.macaddress})
      insertStation(station, req.ip, function(error, success) {
        if (success) {
          res.send(201)
        }
      })
    }
    if (doc) {
      if (doc.ip !== req.ip) {
        removeIp(req.ip)
        updateIp(req.params.macaddress, req.ip)
      }
      res.send(200, doc)
    }
  })
}

exports.actionStation = function(req, res) {
  db.get('stations', { 'settings.macaddress': req.params.macaddress }, function (error, doc) {
    if (doc === null) {
      res.send(204)
    }
    if (doc) {
      station.action(req.body, doc)
      res.send(200, doc)
    }
  })
}

exports.storeStation = function(req, res) {
  db.get('stations', { 'settings.macaddress': req.body.macaddress }, function (error, doc) {

    if (req.headers['station-mgr']) {
      req.body.ip = req.ip
    }
    
    var settings = new StationSettings(req.body)
    if (!error && doc === null) {
      insertStation(settings, req.body.ip, function(error, success) {
        if (error) {
          res.send(500, error)
        }
        if (success) {
          res.send(200, true)
        }
      })
    }
    if (doc) {
      db.updateRaw('stations', { "settings.macaddress": req.body.macaddress }, { $set: { "settings": settings } }, function(error, success) {
        if (error) {
          res.send(500, error)
        }
        if (success) {
          res.send(200, true)
        }
      })
    }
    if (error) {
      console.log(error)
      res.send(500, error)
    }
  })
}

exports.deleteStation = function(req, res) {
  db.remove('stations', {'settings.macaddress': req.params.macaddress}, function(error, removed) {
    if (removed) {
      res.send(204, true)
    }
  })
}

var tablesDocLookups = {
  stations: {
    valueKey: 'macaddress',
    key: 'settings.macaddress'
  }
}

var tableNames = Object.keys(tablesDocLookups)

exports.listDocs = function(req, res) {
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
    var tableInfo = tablesDocLookups[req.params.db]
    query[tableInfo.key] = req.params.id;
    db.get(req.params.db, query, function (error, doc) {
      if (error) {
        res.send(500, error)
      }
      if (doc === null) {
        res.send(404, tableInfo)
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

exports.partial = function(req, res) {
  if (tableNames.indexOf(req.params.db) !== -1) {
    var query = {}
    var tableInfo = tablesDocLookups[req.params.db]
    query[tableInfo.key] = req.params.id;
    
    partial = {}
    if (req.body instanceof Array) { 
      for (var i in req.body) {
        partial[req.body[i].key] = req.body[i].value
      }
    }
    else {
      partial[req.body.key] = req.body.value
    }

    db.update(req.params.db, query, partial, function (error, doc) {
      if (error) {
        res.send(500)
      }
      if (doc) {
        if (!req.headers['station-mgr']){
          station.update(doc)
        }
        res.send(200, partial)
      }
      if (!error && !doc) {
        res.send(404)
      }
    })
  }  
  else {
    res.send(404)
  }
}
