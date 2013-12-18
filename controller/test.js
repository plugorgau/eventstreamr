var request = require('request');

request('http://127.0.0.1:5001/api/station/00-21-5c-02-02-27', { 
  method: 'GET'
}, function(error, response, data) {
  console.log('test', error || response)
})
