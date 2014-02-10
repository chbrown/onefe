/*jslint node: true */
var async = require('async');
var fs = require('fs');
var logger = require('loge');
var redis = require('redis');
var sv = require('sv');
var open_exchange_rates = require('open-exchange-rates');

var pushAll = function(array, xs) { return Array.prototype.push.apply(array, xs); };

var ns = function(/* parts... */) {
  // var parts = Array.prototype.slice.call(arguments, 0);
  return Array.prototype.concat.apply(['onefe'], arguments).join(':');
};

// GLOBALS:
exports.currencies = {};
exports.history = [];

var refreshHistory = function() {
  var r = redis.createClient();
  r.keys(ns('*'), function(err, all_keys) {
    // sort the keys and keep only the 100 most recent
    var keys = all_keys.sort().slice(-100);
    if (keys.length) {
      async.map(keys, r.hgetall.bind(r), function(err, history) {
        // update by reference
        exports.history.length = 0;
        pushAll(exports.history, history);
      });
    }
    else {
      logger.error('Rates cannot be found; no "%s" keys exist', ns('*'));
    }
  });
};

var downloadRates = function() {
  var r = redis.createClient();
  open_exchange_rates.load(function(err) {
    if (err) return logger.error(err);

    var date = new Date(open_exchange_rates.timestamp);
    var rates = open_exchange_rates.rates;
    rates.timestamp = open_exchange_rates.timestamp;
    // truncate fractional seconds and timezone from date string
    var date_string = date.toISOString().replace(/\..+/g, '').replace(/:/g, '-');
    var key = ns(date_string);
    // `key` will be something like "onefe:2014-02-10T01-01-02"
    r.hmset(key, rates, function(err) {
      if (err) return logger.error(err);

      logger.debug('Fetched rates into redis key: %s', key);
    });
  });
};

var loadCurrencies = function() {
  var parser = fs.createReadStream('currencies.tsv', {encoding: 'utf8'}).pipe(new sv.Parser());
  parser.on('error', function(err) {
    logger.error('Error in loadCurrencies:', err);
  });
  parser.on('data', function(row) {
    exports.currencies[row.abbr] = row.name;
  });
  parser.on('end', function() {
    logger.info('Finished reading currencies');
  });
};

// just loading this module triggers the async loops / workers
var refreshHistory_interval = 60*1000;
logger.info('Starting refreshHistory loop (interval=%d ms)', refreshHistory_interval);
setInterval(refreshHistory, refreshHistory_interval);
refreshHistory();

// Every time we fetch rates from an API, we store them in redis, with a key
// timestamped like "onefe:2014-02-10T01-01-02", i.e., UTC and a format that
// resembles ISO-8601
var milliseconds_per_month = 60*60*24*31*1000;
// "open" exchange rates closes its rates after 1000 queries per month
var queries_per_month = 1000;
var downloadRates_interval = milliseconds_per_month / queries_per_month;
// downloadRates_interval comes out to 44.64 minutes
logger.info('Starting downloadRates loop (interval=%d ms)', downloadRates_interval);
setInterval(downloadRates, downloadRates_interval);
// downloadRates();
