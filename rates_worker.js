var exchange = require('exchange-rates'),
  redis = require('redis').createClient(),
  pub_redis = require('redis').createClient(),
  seconds_per_month = 60*60*24*31,
  queries_per_month = 1000,
  seconds_per_query = seconds_per_month / queries_per_month;

// seconds_per_query = 3;
// Everytime we fetch rates from an API, we'll store them as a redis key: "forex:YYYY-MM-DDTHH:MM:SS"
//   that is, with the date in UTC ISO-8601, at the second.
// every 44.64 minutes, except that setInterval takes its timeout in milliseconds
setInterval(function() {
  // console.log('Fetching...');
  exchange.load(function(err, rates_json) {
    if (err) console.log(err);
    var payload = JSON.parse(rates_json),
      date = new Date(payload.timestamp*1000),
      date_iso8601 = date.toISOString().split('.')[0],
      redis_key = 'forex:' + date_iso8601;
    redis.set(redis_key, JSON.stringify(payload.rates), function(err) {
      if (err) console.log(err);
      console.log('Fetched rates into key: ' + redis_key);
      pub_redis.publish("forex", JSON.stringify({date: date_iso8601, rates: payload.rates}));
    });
  });
}, seconds_per_query*1000);
console.log('Fetching every ' + seconds_per_query + ' seconds.');
