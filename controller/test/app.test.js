process.env.NODE_ENV = 'development';
var app = require('../app');
var request = require('supertest');
var chai = require("chai");
chai.should();
chai.use(require('chai-things'));

// check admin page 
describe('GET /admin', function(){
  it('admin page should load', function(done){
    request(app)
      .get('/admin')
      .expect(200, done);
  })
})

// register a station
describe('POST /api/station/D0:FB:DB:D4:21:15', function(){
  it('Station should register', function(done){
    request(app)
      .post('/api/station/D0:FB:DB:D4:21:15')
      .expect(201, done);
  })
})

// update station ip
describe('POST /api/station/D0:FB:DB:D4:21:15', function(){
  it('Station should update it\'s ip', function(done){
    request(app)
      .post('/api/station/D0:FB:DB:D4:21:15')
      .expect(200, done);
  })
})

// post config as station
describe('POST /api/station', function(){
  it('Config for station should be updated and ip address set', function(done){
    request(app)
      .post('/api/station')
      .set('station-mgr','1') 
      .set('Content-Type', 'application/json')
      .send(
            {
              "device_control" : {
                 "api" : {
                    "run" : "1"
                 },
                 "dvmon" : {
                    "run" : "0"
                 }
              },
              "devices" : "all",
              "macaddress" : "D0:FB:DB:D4:21:15",
              "mixer" : {
                 "host" : "localhost",
                 "port" : "1234"
              },
              "nickname" : "stationtest",
              "record_path" : "/tmp/$room/$date",
              "roles" : [
                { "role": "mixer" },
                { "role": "record" },
                { "role": "ingest" },
                { "role": "stream" }
              ],
              "room" : "",
              "run" : "0",
              "stream" : {
                 "host" : "1.2.3.4",
                 "password" : "password",
                 "port" : "1337",
                 "stream" : "test.ogg"
              }
            }
      )
      .expect(200, done);
  })
})

// Get station information
describe('GET /api/stations/D0:FB:DB:D4:21:15', function(){
  it('Get station details', function(done){
    request(app)
      .get('/api/stations/D0:FB:DB:D4:21:15')
      .expect('Content-Type', /json/)
      .expect(200)
      .end(function(err, res) {
        // ip
        res.body.ip.should.equal('127.0.0.1');
        // settings object
        res.body.should.have.property('settings').to.be.an('object');
        // device control object
        res.body.settings.should.have.property('device_control').to.be.an('object');
        res.body.settings.should.have.property('device_control').to.have.deep.property('api.run', '1');
        res.body.settings.should.have.property('device_control').to.have.deep.property('dvmon.run', '0');
        // devices
        res.body.settings.should.have.property('devices').to.equal('all')
        // mac address
        res.body.settings.should.have.property('macaddress').to.equal('D0:FB:DB:D4:21:15')
        // mixer object
        res.body.settings.should.have.property('mixer').to.be.an('object')
        res.body.settings.mixer.host.should.equal('localhost');
        res.body.settings.mixer.port.should.equal('1234');
        // nickname
        res.body.settings.should.have.property('nickname').to.equal('stationtest')
        // record path
        res.body.settings.should.have.property('record_path').to.equal('/tmp/$room/$date')
        // roles array
        res.body.settings.should.have.property('roles').to.be.an('array')
        res.body.settings.roles.should.contain.an.item.with.property('role', 'mixer');
        res.body.settings.roles.should.contain.an.item.with.property('role', 'record');
        res.body.settings.roles.should.contain.an.item.with.property('role', 'ingest');
        res.body.settings.roles.should.contain.an.item.with.property('role', 'stream');
        // room
        res.body.settings.should.have.property('room').to.be.empty
        // run
        res.body.settings.should.have.property('run').to.be.equal('0')
        // stream object
        res.body.settings.should.have.property('stream').to.be.an('object')
        res.body.settings.stream.host.should.equal('1.2.3.4');
        res.body.settings.stream.password.should.equal('password');
        res.body.settings.stream.port.should.equal('1337');
        res.body.settings.stream.stream.should.equal('test.ogg');

        done();
      });
  })
})

// delete a station
describe('DEL /api/station/D0:FB:DB:D4:21:15', function(){
  it('Station should be deleted', function(done){
    request(app)
      .del('/api/station/D0:FB:DB:D4:21:15')
      .expect(204, done);
  })})
