/*jslint node: true */
var _ = require('underscore');
var amulet = require('amulet');
var Router = require('regex-router');

var R = new Router(function(req, res) {
  res.die(404, 'No resource at: ' + req.url);
});

// importing exchange triggers all of its related workers
var exchange = require('../exchange');

R.any(/^\/static/, require('./static'));

/** GET /
Render page with the latest rates and information about the currencies */
R.get('/', function(req, res) {
  amulet.stream(['layout.mu', 'index.mu'], {
    current_rates: _.last(exchange.history),
    currencies: exchange.currencies,
  }).pipe(res);
});

/** GET /history.json
Return up to last 100 data points for each currency */
R.get('/history.json', function(req, res) {
  res.json(exchange.history);
});

module.exports = R.route.bind(R);
