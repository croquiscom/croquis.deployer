var forever = require('forever');
var path = require('path');
var coffee_path = path.resolve(require.resolve('coffee-script/register'), '../bin/coffee');

exports.start = function (script) {
  forever.list(false, function (error, list) {
    if (list) {
      list = list.filter(function (p) {
        return p.file===script;
      });
    }
    if (list && list.length>0) {
      forever.log.info('Reload script: ' + script);
      forever.kill(list[0].pid, false, 'SIGHUP', function () {});
    } else {
      forever.log.info('Start script: ' + script);
      options = {
        command: coffee_path,
        minUptime: 10000,
        spinSleepTime: 10000,
        options: ['-l']
      };
      forever.startDaemon(script, options);
    }
  });
};

exports.stop = function (script) {
  forever.log.info('Stop script: ' + script);
  forever.stop(script).on('error', function () {
  }).on('stop', function () {
  });
};
