var j, len, logstream, openLogFile, ref, root;

const cluster = require('cluster');
const domain = require('domain');
const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

let project_root = process.env.PROJECT_ROOT;
if (/versions\/\d{4}-\d{2}-\d{2},\d{2}-\d{2},[a-z0-9]{7}$/.test(project_root)) {
  project_root = path.resolve(project_root, '..', '..', 'current');
}
project_root = path.relative(process.cwd(), project_root);
if (!project_root) {
  project_root = '.';
}

const app_dir = project_root + '/app';
const config_dir = project_root + '/config';

let shutdowning = false;

const config = yaml.safeLoad(fs.readFileSync(project_root + '/deploy.yaml', 'utf-8'));
let do_watch = false;
let devel_mode = false;
let redirect_log = false;

ref = process.argv;
for (j = 0, len = ref.length; j < len; j++) {
  const arg = ref[j];
  if (arg === '-w') {
    do_watch = true;
  }
  if (arg === '-d') {
    devel_mode = true;
  }
  if (arg === '-l') {
    redirect_log = true;
  }
}

if (redirect_log) {
  logstream = void 0;
  openLogFile = function() {
    if (logstream) {
      logstream.close();
    }
    logstream = fs.createWriteStream(root + "/" + config.project + ".log", {
      flags: 'a+',
      mode: '0644',
      encoding: 'utf8'
    });
  };
  root = path.join(process.env.HOME, '.croquis');
  try {
    fs.mkdirSync(root, '0755');
  } catch (error) {}
  openLogFile();
  process.stdout.write = function(chunk, encoding, cb) {
    logstream.write(chunk, encoding, cb);
  };
  process.stderr.write = function(chunk, encoding, cb) {
    logstream.write(chunk, encoding, cb);
  };
  process.on('SIGUSR2', function() {
    openLogFile();
  });
}

function log(msg) {
  console.log("[" + (Date.now()) + "] [deployer] " + msg);
}

function debug(msg) {
  // console.log(msg);
}

function exitIfNoWorkers() {
  if (Object.keys(cluster.workers).length === 0) {
    console.log("[" + (Date.now()) + "] [deployer] Terminate");
    process.exit(0);
  }
}

function registerHandlers() {
  cluster.on('exit', function(worker, code, signal) {
    var options;
    if (shutdowning) {
      exitIfNoWorkers();
      return;
    }
    if (!worker.prevent_restart) {
      options = worker.options;
      if (options["try"] < 3) {
        fork(options);
      }
    }
  });
}

function fork(options) {
  var worker;
  log('forking... ' + options.exec);
  options["try"]++;
  cluster.setupMaster();
  cluster.settings.exec = __dirname + '/run_app.js';
  cluster.settings.args = [project_root, options.exec];
  if (redirect_log) {
    cluster.settings.silent = true;
  }
  worker = cluster.fork({
    WORKER_NUM: options.num
  });
  worker.options = options;
  if (redirect_log) {
    worker.process.stdout.on('data', function(data) {
      logstream.write(data);
    });
    worker.process.stderr.on('data', function(data) {
      logstream.write(data);
    });
  }
  worker.once('listening', function() {
    worker.options["try"] = 0;
  });
  return worker;
}

function startWorkers() {
  var count, i, k, l, len1, numCPUs, ref1, ref2, worker;
  numCPUs = require('os').cpus().length;
  if (devel_mode) {
    numCPUs = 1;
  }
  ref1 = config.workers;
  for (k = 0, len1 = ref1.length; k < len1; k++) {
    worker = ref1[k];
    if (devel_mode && worker.production_only === true) {
      continue;
    }
    if (worker.instances === 'max') {
      count = numCPUs;
    } else {
      count = parseInt(worker.instances);
    }
    if (!(count > 0)) {
      count = 1;
    }
    for (i = l = 0, ref2 = count; 0 <= ref2 ? l < ref2 : l > ref2; i = 0 <= ref2 ? ++l : --l) {
      fork({
        exec: app_dir + '/' + worker.app,
        num: i,
        graceful_exit: worker.graceful_exit,
        "try": 0
      });
    }
  }
}

function restartWorkers() {
  var id, killOne, ref1, worker, workers;
  workers = [];
  ref1 = cluster.workers;
  for (id in ref1) {
    worker = ref1[id];
    workers.push(worker);
  }
  if (workers.length === 0) {
    // worker가 정상적으로 뜨지 않은 경우 그냥 시작한다
    startWorkers();
    return;
  }
  killOne = function() {
    if (workers.length > 0) {
      worker = workers.pop();
      worker.once('disconnect', function() {
        killOne();
      });
      worker.options["try"] = 0;
      if (worker.options.graceful_exit) {
        worker.prevent_restart = true;
        fork(worker.options).once('listening', function() {
          debug('killing... ' + worker.options.exec);
          process.kill(worker.process.pid, 'SIGTERM');
        }).once('exit', function() {
          // fork에 문제가 생긴 경우 kill 과정을 중단한다
          workers.length = 0;
        });
      } else {
        debug('killing... ' + worker.options.exec);
        process.kill(worker.process.pid, 'SIGTERM');
      }
    }
  };
  killOne();
}

function startWatch() {
  var extensions, ignoreDirectories, traverse, watch;
  ignoreDirectories = [];
  extensions = ['.js', '.coffee', '.ts'];
  watch = function(file) {
    if (extensions.indexOf(path.extname(file)) < 0) {
      return;
    }
    // debug('watching... ' + file.substr(project_root.length+1));
    fs.watchFile(file, {
      interval: 100
    }, function(curr, prev) {
      if (curr.mtime > prev.mtime) {
        log('changed - ' + file);
        restartWorkers();
      }
    });
  };
  traverse = function(file) {
    fs.stat(file, function(err, stat) {
      if (err) {
        return;
      }
      if (stat.isDirectory()) {
        if (ignoreDirectories.indexOf(path.basename(file)) >= 0) {
          return;
        }
        fs.readdir(file, function(err, files) {
          files.map(function(f) {
            return file + "/" + f;
          }).forEach(traverse);
        });
      } else {
        watch(file);
      }
    });
  };
  traverse(app_dir);
  traverse(config_dir);
}

log("Start at " + (fs.realpathSync(project_root)));
registerHandlers();
startWorkers();
if (do_watch) {
  startWatch();
}

process.on('SIGHUP', function() {
  log("Restart at " + (fs.realpathSync(project_root)));
  restartWorkers();
});
process.on('SIGINT', function() {
  shutdowning = true;
  exitIfNoWorkers();
});
process.on('SIGTERM', function() {
  shutdowning = true;
  exitIfNoWorkers();
  for (const id in cluster.workers) {
    const worker = cluster.workers[id];
    process.kill(worker.process.pid, 'SIGTERM');
  }
});

// server.js가 그냥 종료되면 forever가 다시 띄운다
// 혹시 worker에 문제가 있어서 실행이 안 되도 server.js는 유지되게 한다
setTimeout((function() {}), 1000 * 1000 * 1000);
