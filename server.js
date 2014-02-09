#!/usr/bin/env node
/*jslint node: true */
var fs = require('fs');
var path = require('path');
var http = require('http-enhanced');
var logger = require('loge');
var amulet = require('amulet');
var Router = require('regex-router');
var redis = require('redis');
var exchange = require('open-exchange-rates');

amulet.set({root: path.join(__dirname, 'templates')});

var currencies = require('./currencies');
var pubsub_redis = redis.createClient();

var main_redis = redis.createClient();

var ns = function(/* parts... */) {
  var parts = Array.prototype.slice.call(arguments, 0);
  return 'onefe:' + parts.join(':');
};

var all_rates = {};
var most_recent = null;
main_redis.keys('forex:*', function(err, rate_keys) {
  main_redis.mget(rate_keys, function(err, cached_rates) {
    for (var i = 0, l = rate_keys.length; i < l; i++) {
      all_rates[rate_keys[i]] = JSON.parse(cached_rates[i]);
    }
  });
});

pubsub_redis.on('message', function (channel, message) {
  var payload = JSON.parse(message);  // message = {date: date_iso8601, rates: payload.rates}
  console.log('Got pubsub_redis message from worker: ' + payload.date.toString());
  all_rates[payload.date] = payload.rates;
  most_recent = payload.rates;
});
pubsub_redis.subscribe('forex');


function refreshMostRecent() {
  console.log('refreshMostRecent');
  var keys = Object.keys(all_rates).sort();
  var most_recent_key = keys[keys.length - 1];
  most_recent = all_rates[most_recent_key];
}

var R = new Router(function(req, res) {
  res.die(404, 'No resource at: ' + req.url);
});

R.get('/', function(req, res) {
  if (!most_recent) refreshMostRecent();

  amulet.stream(['layout.mu', 'index.mu'], {
    rates: most_recent,
    currencies: currencies
  }).pipe(res);
});

R.get('/histor', function(req, res) {
  var keys = Object.keys(all_rates).sort();
  var historical_keys = keys.slice(keys.length - 100);
  var historical_rates = historical_keys.map(function(key) {
    return {
      dt: key.replace(/forex:/, ''),
      rates: all_rates[key]
    };
  });
  res.json(historical_rates);
});


var startWorker = function() {
  var seconds_per_month = 60*60*24*31;
  var queries_per_month = 1000;
  var seconds_per_query = seconds_per_month / queries_per_month;

  // Everytime we fetch rates from an API, we'll store them as a redis key: 'forex:YYYY-MM-DDTHH:MM:SS'
  //   that is, with the date in UTC ISO-8601, at the second.
  // every 44.64 minutes, except that setInterval takes its timeout in milliseconds
  var work = function() {
    var r = redis.createClient();
    exchange.load(function(err) {
      if (err) return logger.error(err);

      var date_string = new Date(exchange.timestamp).toISOString().replace(/\..+/, '');
      var redis_key = ns(date_string);
      r.set(redis_key, JSON.stringify(exchange.rates), function(err) {
        if (err) return logger.error(err);

        logger.debug('Fetched rates into redis key: %s', redis_key);
        // r.publish('forex', JSON.stringify({date: date_string, rates: exchange.rates}));
      });
    });
  };
  logger.info('Starting worker loop (interval=%s seconds)', seconds_per_query.toFixed(2));
  setInterval(work, seconds_per_query*1000);
};

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

  exchange.set({app_id: argv.exchange_app_id});

  startWorker();

  http.createServer(function(req, res) {
    // req.cookies = new Cookies(req, res);
    var started = Date.now();
    res.on('finish', function() {
      logger.debug('duration', {url: req.url, method: req.method, ms: Date.now() - started});
    });

    R.route(req, res);
  }).listen(argv.port, argv.hostname, function() {
    logger.info('listening on http://%s:%d', argv.hostname, argv.port);
  });
}
