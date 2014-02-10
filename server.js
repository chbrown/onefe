#!/usr/bin/env node
/*jslint node: true */
var open_exchange_rates = require('open-exchange-rates');
var logger = require('loge');
var http = require('http-enhanced');
var path = require('path');
var amulet = require('amulet');
amulet.set({root: path.join(__dirname, 'templates')});

if (require.main === module) {
  var optimist = require('optimist')
    .describe({
      hostname: 'hostname to listen on',
      port: 'port to listen on',
      exchange_app_id: 'App ID at openexchangerates.org',
    })
    .default({
      hostname: '127.0.0.1',
      port: 6501,
      exchange_app_id: '28967c4d6b86479bb36a407440bc6f0c',
    });

  var argv = optimist.argv;

  open_exchange_rates.set({app_id: argv.exchange_app_id});

  var root_controller = require('./controllers');

  http.createServer(function(req, res) {
    var started = Date.now();
    res.on('finish', function() {
      logger.debug('duration', {url: req.url, method: req.method, ms: Date.now() - started});
    });

    root_controller(req, res);
  }).listen(argv.port, argv.hostname, function() {
    logger.info('listening on http://%s:%d', argv.hostname, argv.port);
  });
}
