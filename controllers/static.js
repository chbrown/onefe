/*jslint node: true */
var path = require('path');
var send = require('send');
var Router = require('regex-router');
var logger = require('loge');

var R = new Router(function(req, res) {
  res.die(404, 'No resource at: ' + req.url);
});

R.get(/^\/static\/([^?]+)(\?|$)/, function(req, res, m) {
  logger.debug('send /static: %s', m[1]);
  send(req, m[1])
    .root(path.join(__dirname, '..', 'static'))
    .on('error', function(err) {
      res.die(err.status || 500, 'send error: ' + err.message);
    })
    .on('directory', function() {
      res.die(404, 'No resource at: ' + req.url);
    })
    .pipe(res);
});

module.exports = R.route.bind(R);
