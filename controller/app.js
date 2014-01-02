'strict'

/**
 * Module dependencies.
 */
var express = require('express');
var adminroutes = require('./routes/admin');
var api = require('./routes/api');
var http = require('http');
var path = require('path');
var request = require('request');

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
if ('development' == process.env.NODE_ENV) {
  app.use(express.errorHandler());
  module.exports = app;
}

app.locals(config.event)

app.get('/admin', adminroutes.dashboard)

app.get('/api/:db', api.listDocs)
app.get('/api/:db/:id', api.getDocument)
app.post('/api/:db/:id/:partial', api.partial)

app.post('/api/station', api.storeStation)
app.post('/api/station/:macaddress', api.registerStation)
app.del('/api/station/:macaddress', api.deleteStation)

var server = http.createServer(app)
var io = require('socket.io').listen(server)

server.listen(app.get('port'), function(){
  console.log('Eventstreamr controller listening on port ' + app.get('port'));
});

var updates = io.sockets.on('connection', function (socket) {
  console.log('new change subscriber connected.')
});

app.post('/feed', function(req, res) {
  updates.emit('change', req.body)
  res.send(200)
})
