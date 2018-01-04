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
let logstream;

for (const arg of process.argv) {
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
  const root = path.join(process.env.HOME, '.croquis');
  const openLogFile = function() {
    if (logstream) {
      logstream.close();
    }
    logstream = fs.createWriteStream(root + "/" + config.project + ".log", {
      flags: 'a+',
      mode: '0644',
      encoding: 'utf8'
    });
  };
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
  console.log(`[${new Date().toISOString()}] [deployer] ${msg}`);
}

function debug(msg) {
  // console.log(msg);
}

function exitIfNoWorkers() {
  if (Object.keys(cluster.workers).length === 0) {
    console.log(`[${new Date().toISOString()}] [deployer] Terminate`);
    process.exit(0);
  }
}

function registerHandlers() {
  cluster.on('exit', function(worker, code, signal) {
    if (shutdowning) {
      exitIfNoWorkers();
      return;
    }
    if (!worker.prevent_restart) {
      const options = worker.options;
      if (options["try"] < 3) {
        fork(options);
      }
    }
  });
}

function fork(options) {
  log('forking... ' + options.exec);
  options["try"]++;
  cluster.setupMaster();
  cluster.settings.exec = __dirname + '/run_app.js';
  cluster.settings.args = [project_root, options.exec];
  if (redirect_log) {
    cluster.settings.silent = true;
  }
  const worker = cluster.fork({
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
  const numCPUs = devel_mode ? 1 : require('os').cpus().length;
  for (const worker of config.workers) {
    if (devel_mode && worker.production_only === true) {
      continue;
    }
    let count;
    if (worker.instances === 'max') {
      count = numCPUs;
    } else {
      count = parseInt(worker.instances);
    }
    if (!(count > 0)) {
      count = 1;
    }
    for (let i = 0 ; i < count ; i++) {
      fork({
        exec: app_dir + '/' + worker.app,
        num: i,
        graceful_exit: worker.graceful_exit,
        "try": 0
      });
    }
  }
}

let restarting = false;
function restartWorkers() {
  if (restarting) {
    return;
  }
  const workers = [];
  for (const id in cluster.workers) {
    const worker = cluster.workers[id];
    workers.push(worker);
  }
  if (workers.length === 0) {
    // worker가 정상적으로 뜨지 않은 경우 그냥 시작한다
    startWorkers();
    return;
  }
  restarting = true;
  const killOne = function() {
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
    } else {
      restarting = false;
    }
  };
  // 동시에 여러 파일이 수정되는 경우를 위해(예 git pull) 모든 수정이 완료될만한 시간까지 기다린다
  setTimeout(killOne, 1000);
}

function startWatch() {
  const ignoreDirectories = [];
  const extensions = ['.js', '.coffee', '.ts'];
  const watch = function(file) {
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
  const traverse = function(file) {
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
