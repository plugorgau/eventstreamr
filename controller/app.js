'strict'

/**
 * Module dependencies.
 */

var express = require('express');
var adminroutes = require('./routes/admin');
var http = require('http');
var path = require('path');
var request = require('request');

// datastore connection

var Datastore = require('nedb')
  , db = new Datastore({ filename: 'storage/stations.db' , autoload: true});

// config
var config = require('../config.json')

var app = express();

app.enable('trust proxy');

// all environments
app.set('port', 5001);
app.set('views', __dirname + '/views');
app.set('view engine', 'jade');
app.use(express.favicon());
app.use(express.logger('dev'));
app.use(express.bodyParser());
app.use(express.methodOverride());
app.use(app.router);
app.use(express.static(path.join(__dirname, 'public')));

// development only
if ('development' == app.get('env')) {
  app.use(express.errorHandler());
}

app.locals(config.event)

var storeStation = function(settings, ip) {
  var document = {
    ip: ip || null,
    settings: settings
  }
  db.insert(document, function (err, newDoc) {
    
  })
}

var removeIp = function(ip) {
  db.update({ ip: ip }, { $unset: { ip: true } }, {}, function () {});
}

var updateIp = function(mac, ip) {
  db.update({ "setings.mac": mac }, { $set: { ip: ip } }, {}, function () {});
}

var Station = function(mac, roles, room, nickname) {
  return {
    mac: mac,
    roles: roles || [],
    room: room || null,
    nickname: nickname || null
  }
}

var getStation = function(mac, ip) {
  removeIp(ip)
  request('http://' +ip +':3000/settings/'+mac, function (error, response, body) {
    if (!error) {
      console.log(response.statusCode)
      if (response.statusCode == 200) {
        console.log(response.body)
        storeStation(response.body, ip)
      }
      if (response.statusCode == 204) {
        
      }
      if (response.statusCode == 400) {
        getStation(response.body.mac, ip)
      }
    }
  })
}

app.get('/admin', adminroutes.dashboard)

app.get('/station/:mac', function(req, res) {
  db.find({ 'settings.mac': req.params.mac }, function (err, docs) {
    if (docs) {
      if (!docs.length) {
        getStation(req.params.mac, req.ip)
        res.send(204, {
          "status": 'unknown'
        })
      }
      if (docs.length) {
        var doc = docs[0]
        if (doc.ip !== req.ip) {
          removeIp(req.ip)
          updateIp(req.params.mac, req.ip)
        }
        res.send(200, docs[0])
      }
    }
  });
});

app.get('/api/stations', function(req, res) {
  db.find({}, function (err, docs) {
    if (err) {
      res.send(500, err)
    }
    if (docs) {
      res.send(docs)
    }
  });
})

app.post('/api/station', function(req, res) {
  var station = new Station(req.body.mac.replace(/:\s*/g, "-"), req.body.roles, req.body.room, req.body.nickname)
  storeStation(station)
  res.send(true)
})

app.del('/api/station/:mac', function(req, res) {
  db.remove({'_id': req.params.mac}, {}, function(err, removed) {
    if (removed) {
      res.send(true)
    }
  })
})

http.createServer(app).listen(app.get('port'), function(){
  console.log('Eventstreamr controller listening on port ' + app.get('port'));
});
