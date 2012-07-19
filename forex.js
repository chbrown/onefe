#!/usr/bin/env node
var __ = require('underscore')._,
    fs = require('fs'),
    path = require('path'),
    http = require('http'),
    // Cookies = require('cookies'),
    amulet = require('amulet'),
    wrappers = require('wrappers'),
    argv = require('optimist').argv,
    redis = require('redis').createClient(),
    sub_redis = require('redis').createClient(),
    currencies = require('./currencies');
    
var host = argv.host || '127.0.0.1',
    port = argv.port || 3261;

amulet.set({minify: true, root: path.join(__dirname, 'templates')});

var rates = {};
redis.keys('forex:*', function(err, rate_keys) {
  // rate_keys.forEach(function(rate_key) {
  // cached_rates.forEach(function(
  redis.mget(rate_keys, function(err, cached_rates) {
    for (var i = 0, l = rate_keys.length; i < l; i++) {
      rates[rate_keys[i]] = JSON.parse(cached_rates[i]);
    }
  });
});
sub_redis.on('message', function (channel, message) {
  var payload = JSON.parse(message);  // message = {date: date_iso8601, rates: payload.rates}
  rates[payload.date] = payload.rates;
});
sub_redis.subscribe('forex');


http.createServer(function(req, res) {
  // console.log('ten dollar? ' + fx(10).from('USD').to('GBP').toFixed(2));
  var keys = Object.keys(rates).sort(),
    most_recent = keys[keys.length - 1],
    most_recent_rates = rates[most_recent];
  
  res.writeHead(200, {"Content-Type": "text/html"});
  amulet.render(res, ['layout.mu', 'index.mu'], {rates: most_recent_rates});
}).listen(port, host, function() {
  console.log(__filename + ' server running on ' + host + ':' + port);
});
