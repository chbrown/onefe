#!/usr/bin/env node
var __ = require('underscore')._,
    fs = require('fs'),
    path = require('path'),
    http = require('http'),
    amulet = require('amulet'),
    wrappers = require('wrappers'),
    argv = require('optimist').argv,
    redis = require('redis').createClient(),
    sub_redis = require('redis').createClient(),
    currencies = require('./currencies');
    
var host = argv.host || '127.0.0.1',
    port = argv.port || 3261;

amulet.set({minify: true, root: path.join(__dirname, 'templates')});

var all_rates = {}, most_recent;
redis.keys('forex:*', function(err, rate_keys) {
  redis.mget(rate_keys, function(err, cached_rates) {
    for (var i = 0, l = rate_keys.length; i < l; i++) {
      all_rates[rate_keys[i]] = JSON.parse(cached_rates[i]);
    }
  });
});

sub_redis.on('message', function (channel, message) {
  var payload = JSON.parse(message);  // message = {date: date_iso8601, rates: payload.rates}
  all_rates[payload.date] = payload.rates;
  most_recent = payload.rates;
});
sub_redis.subscribe('forex');

function refreshMostRecent() {
  console.log('refreshMostRecent');
  var keys = Object.keys(all_rates).sort(),
    most_recent_key = keys[keys.length - 1];
  most_recent = all_rates[most_recent_key];
}

http.createServer(function(req, res) {
  console.time(req.url);
  if (req.url.match(/histor/)) {
    var keys = Object.keys(all_rates).sort(),
      historical_keys = keys.slice(keys.length - 100),
      historical_rates = historical_keys.map(function(key) {
        return {
          dt: key.replace(/forex:/, ''),
          rates: all_rates[key]
        };
      });
    res.writeHead(200, {"Content-Type": "application/json"});
    res.end(JSON.stringify(historical_rates));
    console.timeEnd(req.url);
  }
  else {
    if (!most_recent) refreshMostRecent();
    var context = {rates: most_recent, currencies: currencies};
    res.writeHead(200, {"Content-Type": "text/html"});
    amulet.render(res, ['layout.mu', 'index.mu'], context, function() {
      console.timeEnd(req.url);
    });
  }
}).listen(port, host, function() {
  console.log(__filename + ' server running on ' + host + ':' + port);
});
