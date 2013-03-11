var exchange = require('open-exchange-rates');
var redis = require('redis');
var seconds_per_month = 60*60*24*31;
var queries_per_month = 1000;
var seconds_per_query = seconds_per_month / queries_per_month;

exchange.set({app_id: '28967c4d6b86479bb36a407440bc6f0c'});

var pub_redis = redis.createClient();
// Everytime we fetch rates from an API, we'll store them as a redis key: 'forex:YYYY-MM-DDTHH:MM:SS'
//   that is, with the date in UTC ISO-8601, at the second.
// every 44.64 minutes, except that setInterval takes its timeout in milliseconds
function fetch() {
  exchange.load(function(err) {
    if (err) console.error(err);
    var date = new Date(exchange.timestamp);
    var date_iso8601 = date.toISOString().split('.')[0];
    var redis_key = 'forex:' + date_iso8601;

    redis.set(redis_key, JSON.stringify(exchange.rates), function(err) {
      if (err) console.error(err);
      console.log('Fetched rates into key: ' + redis_key);
      pub_redis.publish('forex', JSON.stringify({date: date_iso8601, rates: exchange.rates}));
    });
  });
}

setInterval(fetch, seconds_per_query*1000);
console.log('Fetching now and every ' + seconds_per_query + ' seconds.');
fetch();
