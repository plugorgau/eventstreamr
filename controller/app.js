
/**
 * Module dependencies.
 */

var express = require('express');
var routes = require('./routes');
var http = require('http');
var path = require('path');
var request = require('request');

var Datastore = require('nedb')
  , db = new Datastore({ filename: 'storage/stations.db' , autoload: true});

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

var storeStation = function(settings, ip) {
  var document = {
    ip: ip,
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
  removeIp(req.ip)
  request('http://' +ip +':3000/settings/'+mac, function (error, response, body) {
    if (!error && response.statusCode == 200) {
      storeStation(response.body)
    }
    if (!error && response.statusCode == 204) {
      var station = new Station(mac)
      request('http://' +ip +':3000/settings', { 
        method: 'POST',
        json: station
      }, function(error, response, data) {
        if (!error && response.statusCode == 201) {
          storeStation(station)
        }
      })
    }
    if (!error && response.statusCode == 400) {
      getStation(response.body.mac, ip)
    }
  })
}

app.get('/station/:mac', function(req, res) {
  db.find({ 'settings.mac': req.params.mac }, function (err, docs) {
    if (docs) {
      if (!docs.length) {
        res.send(204, {
          status: 'unknown'
        })
        getStation(req.params.mac, req.ip)
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

app.get('/admin', function(request, response) {
  response.render('admin/index', {title: 'eventstreamr'})
})

http.createServer(app).listen(app.get('port'), function(){
  console.log('Eventstreamr controller listening on port ' + app.get('port'));
});
