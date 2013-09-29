var request = require('request');

request('http://10.4.1.196:5001/station/00-21-5c-02-02-27', { 
  method: 'GET'
}, function(error, response, data) {
  console.log('test', error || response)
})
