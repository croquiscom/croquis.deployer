var forever = require('forever');
exports.start = function (script, options) {
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
      options.minUptime = 10000;
      options.spinSleepTime = 10000;
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
