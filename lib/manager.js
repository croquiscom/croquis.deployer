var forever = require('forever');
var path = require('path');
var coffee_path = path.resolve(require.resolve('coffee-script/register'), '../bin/coffee');

if (/versions\/\d{4}-\d{2}-\d{2},\d{2}:\d{2},[a-z0-9]{7}$/.test(process.cwd())) {
  process.chdir('../..');
} else if (/current$/.test(process.cwd())) {
  process.chdir('..');
}

function findScript(script, callback) {
  forever.list(false, function (error, list) {
    if (list) {
      list = list.filter(function (p) {
        return p.file===script;
      });
    }
    if (list && list.length>0) {
      callback(null, list[0].pid);
    } else {
      callback(null, null);
    }
  });
}

exports.start = function (script) {
  findScript(script, function (error, pid) {
    if (pid) {
      forever.log.info('Reload script: ' + script);
      forever.kill(pid, false, 'SIGHUP', function () {});
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

exports.sendSignal = function (script, signal) {
  findScript(script, function (error, pid) {
    if (pid) {
      forever.kill(pid, false, signal, function () {});
    }
  });
};
