var jade = require('jade')
  , locals = require('./data.json')
  , fs = require('fs')


// renderFile
var html = jade.renderFile('index.jade', locals);

fs.writeFile("./index.html", html, function() {})
