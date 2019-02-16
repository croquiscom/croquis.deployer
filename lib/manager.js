const cluster = require('cluster');
const path = require('path');
const fs = require('fs');
const yaml = require('js-yaml');
const pm2 = require('pm2');

if (/versions\/\d{4}-\d{2}-\d{2},\d{2}-\d{2},[a-z0-9]{7}$/.test(process.cwd())) {
  process.chdir('../..');
} else if (/current$/.test(process.cwd())) {
  process.chdir('..');
}

var project_root = process.env.PROJECT_ROOT;
if (process.env.FIX_PROJECT_ROOT !== 'true') {
  if (/versions\/\d{4}-\d{2}-\d{2},\d{2}-\d{2},[a-z0-9]{7}$/.test(project_root)) {
    project_root = path.resolve(project_root, '..', '..', 'current');
  }
}
project_root = path.relative(process.cwd(), project_root);
if (!project_root) {
  project_root = '.';
}
const config = yaml.safeLoad(fs.readFileSync(project_root + '/deploy.yaml', 'utf-8'));

function fixScript(script) {
  // script가 버전 디렉토리를 가리키는 경우 프로젝트 디렉토리로 변경한다
  return script.replace(/\/versions\/\d{4}-\d{2}-\d{2},\d{2}-\d{2},[a-z0-9]{7}\//, '/');
}

async function checkWorker(worker) {
  cluster.setupMaster()
  cluster.settings.exec = __dirname + '/run_app.js';
  cluster.settings.args = [project_root, project_root + '/app/' + worker.app];
  cluster.settings.silent = true;
  await new Promise((resolve, reject) => {
    const child = cluster.fork({ WORKER_NUM: 9999, PORT: 9999 });
    const output = [];
    const timer = setTimeout(() => {
      child.kill('SIGTERM');
      const error = new Error('check failed (timeout) - ' + worker.app);
      error.output = Buffer.concat(output).toString();
      reject(error);
    }, 30000);
    child.process.stdout.on('data', (data) => {
      output.push(data);
    });
    child.process.stderr.on('data', (data) => {
      output.push(data);
    });
    child.once('listening', () => {
      clearTimeout(timer);
      child.kill('SIGTERM');
      resolve();
    });
    child.once('exit', () => {
      clearTimeout(timer);
      child.kill('SIGTERM');
      const error = new Error('check failed (exit) - ' + worker.app);
      error.output = Buffer.concat(output).toString();
      reject(error);
    });
  });
}

async function checkWorkers(workers) {
  try {
    await Promise.all(workers.map(checkWorker));
  } catch (error) {
    console.log('checkWorkers failed by', error.message);
    console.log(error.output.replace(/^/gm, '        '));
    process.exit(1);
  }
}

async function check() {
  if (!config.workers) {
    console.log('No workers to start');
    return;
  }
  await checkWorkers(config.workers);
}

async function start() {
  if (!config.workers) {
    console.log('No workers to start');
    return
  }
  try {
    await new Promise((resolve, reject) => {
      pm2.connect((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
    for (const worker of config.workers) {
      await new Promise((resolve, reject) => {
        const script = fixScript(path.resolve(__dirname, 'run_app.js'));
        const options = {
          name: `${config.project}_${worker.app}`,
          cwd: process.cwd(),
          script,
          args: [project_root, project_root + '/app/' + worker.app],
          execMode: 'cluster',
          output: `~/.croquis/${config.project}.log`,
          error: `~/.croquis/${config.project}.log`,
          instances: worker.instances === 'max' ? 0 : Number(worker.instances),
          instance_var: 'PM2_INSTANCE_ID',
          minUptime: '5s',
          maxRestarts: 3,
        };
        pm2.start(options, (error) => {
          if (error) {
            reject(error);
            return;
          }
          resolve();
        })
      });
    }
    pm2.disconnect();
  } catch (error) {
    pm2.disconnect();
    console.log(error);
    process.exit(1);
  }
}

async function stop() {
  try {
    await new Promise((resolve, reject) => {
      pm2.connect((error) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
    for (const worker of config.workers) {
      await new Promise((resolve, reject) => {
        pm2.delete(`${config.project}_${worker.app}`, (error) => {
          if (error) {
            reject(error);
            return;
          }
          resolve();
        })
      });
    }
    pm2.disconnect();
  } catch (error) {
    pm2.disconnect();
    console.log(error);
    process.exit(1);
  }
}

if (require.main === module) {
  if (process.argv[2] === 'check') {
    check();
  } else if (process.argv[2] === 'start') {
    start();
  } else if (process.argv[2] === 'stop') {
    stop();
  }
}
