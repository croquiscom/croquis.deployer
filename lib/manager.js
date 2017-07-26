var cluster = require('cluster');
var forever = require('forever');
var path = require('path');
var fs = require('fs');
var yaml = require('js-yaml');

if (/versions\/\d{4}-\d{2}-\d{2},\d{2}-\d{2},[a-z0-9]{7}$/.test(process.cwd())) {
  process.chdir('../..');
} else if (/current$/.test(process.cwd())) {
  process.chdir('..');
}

var project_root = process.env.PROJECT_ROOT;
if (/versions\/\d{4}-\d{2}-\d{2},\d{2}-\d{2},[a-z0-9]{7}$/.test(project_root)) {
  project_root = path.resolve(project_root, '..', '..', 'current');
}
project_root = path.relative(process.cwd(), project_root);
if (!project_root) {
  project_root = '.';
}
var config = yaml.safeLoad(fs.readFileSync(project_root + '/deploy.yaml', 'utf-8'));

function fixScript(script) {
  // script가 버전 디렉토리를 가리키는 경우 프로젝트 디렉토리로 변경한다
  return script.replace(/\/versions\/\d{4}-\d{2}-\d{2},\d{2}-\d{2},[a-z0-9]{7}\//, '/');
}

function findScript(script) {
  return new Promise(function (resolve) {
    forever.list(false, function (error, list) {
      if (list) {
        list = list.filter(function (p) {
          return p.file===script;
        });
      }
      if (list && list.length>0) {
        resolve(list[0].pid);
      } else {
        resolve(null);
      }
    });
  });
}

function checkWorker(worker) {
  return new Promise(function (resolve, reject) {
    cluster.setupMaster()
    cluster.settings.exec = 'node_modules/.bin/coffee';
    cluster.settings.args = [__dirname + '/run_app.coffee', project_root, project_root + '/app/' + worker.app];
    cluster.settings.silent = true;
    var child = cluster.fork({WORKER_NUM: 300});
    var timer = setTimeout(function () {
      child.kill('SIGTERM');
      reject(new Error('check failed (timeout) - ' + worker.app));
    }, 10000);
    child.once('listening', function () {
      clearTimeout(timer);
      child.kill('SIGTERM');
      resolve();
    });
    child.once('exit', function () {
      clearTimeout(timer);
      child.kill('SIGTERM');
      reject(new Error('check failed (exit) - ' + worker.app));
    });
  });
}

function checkWorkers(workers) {
  return Promise.all(workers.map(checkWorker))
    .catch(function (error) {
      console.log('checkWorkers failed by', error.message);
      process.exit(1);
    });
}

exports.start = function (script) {
  if (!config.workers) {
    console.log('No workers to start');
    return
  }
  script = fixScript(script);
  checkWorkers(config.workers)
    .then(function () {
      findScript(script)
    })
    .then(function (pid) {
      if (pid) {
        forever.log.info('Reload script: ' + script);
        forever.kill(pid, false, 'SIGHUP', function () {});
      } else {
        forever.log.info('Start script: ' + script);
        options = {
          command: 'node_modules/.bin/coffee',
          minUptime: 10000,
          spinSleepTime: 10000,
          args: ['-l']
        };
        forever.startDaemon(script, options);
      }
    })
};

exports.stop = function (script) {
  script = fixScript(script);
  forever.log.info('Stop script: ' + script);
  forever.stop(script).on('error', function () {
  }).on('stop', function () {
  });
};

exports.sendSignal = function (script, signal) {
  script = fixScript(script);
  findScript(script)
    .then(function (pid) {
      if (pid) {
        forever.kill(pid, false, signal, function () {});
      }
    });
};
