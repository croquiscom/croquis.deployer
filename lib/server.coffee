cluster = require 'cluster'
domain = require 'domain'
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

project_root = process.env.PROJECT_ROOT or process.env.PWD or process.cwd()
app_dir = project_root + '/app'
config_dir = project_root + '/config'

config = yaml.safeLoad(fs.readFileSync project_root + '/deploy.yaml', 'utf-8')
for arg in process.argv
  if arg is '-w'
    do_watch = true
  if arg is '-d'
    devel_mode = true
  if arg is '-l'
    redirect_log = true

if redirect_log
  logstream = undefined
  openLogFile = ->
    logstream.close() if logstream
    logstream = fs.createWriteStream "#{root}/#{config.project}.log", flags: 'a+', mode: '0644', encoding: 'utf8'
  root = path.join process.env.HOME, '.croquis'
  try fs.mkdirSync root, '0755'
  openLogFile()
  process.stdout.write = (chunk, encoding, cb) ->
    logstream.write chunk, encoding, cb
  process.stderr.write = (chunk, encoding, cb) ->
    logstream.write chunk, encoding, cb
  process.on 'SIGUSR2', ->
    openLogFile()

log = (msg) ->
  console.log "[#{Date.now()}] [server] #{msg}"

debug = (msg) ->
#  console.log msg

registerHandlers = ->
  cluster.on 'exit', (worker, code, signal) ->
    if not worker.prevent_restart
      fork worker.options

fork = (options) ->
  debug 'forking... ' + options.exec
  cluster.setupMaster()
  cluster.settings.exec = options.exec
  if redirect_log
    cluster.settings.silent = true
  worker = cluster.fork WORKER_NUM: options.num
  worker.options = options
  if redirect_log
    worker.process.stdout.on 'data', (data) ->
      logstream.write data
    worker.process.stderr.on 'data', (data) ->
      logstream.write data
  return worker

startWorkers = ->
  numCPUs = require('os').cpus().length
  if devel_mode
    numCPUs = 1
  for worker in config.workers
    if devel_mode and worker.production_only is true
      continue
    if worker.instances is 'max'
      count = numCPUs
    else
      count = parseInt worker.instances
    if not count>0
      count = 1
    for i in [0...count]
      fork exec: app_dir + '/' + worker.app, num: i, graceful_exit: worker.graceful_exit

destroyWorkers = (immediately) ->
  workers = []
  for id, worker of cluster.workers
    workers.push worker

  if immediately
    for worker in workers
      debug 'killing... ' + worker.options.exec
      process.kill worker.process.pid, 'SIGTERM'
  else
    killOne = ->
      if workers.length > 0
        worker = workers.pop()
        worker.once 'disconnect', ->
          killOne()
        if worker.options.graceful_exit
          worker.prevent_restart = true
          fork worker.options
          .once 'listening', ->
            debug 'killing... ' + worker.options.exec
            process.kill worker.process.pid, 'SIGTERM'
        else
          debug 'killing... ' + worker.options.exec
          process.kill worker.process.pid, 'SIGTERM'
    killOne()

startWatch = ->
  ignoreDirectories = []
  extensions = ['.coffee']
  fs = require 'fs'
  basename = require('path').basename
  extname = require('path').extname

  watch = (file) ->
    return if extensions.indexOf(extname file) < 0
    #debug 'watching... ' + file.substr(project_root.length+1)
    fs.watchFile file, interval: 100, (curr, prev) ->
      if curr.mtime > prev.mtime
          log 'changed - ' + file
          destroyWorkers true

  traverse = (file) ->
    fs.stat file, (err, stat) ->
      return if err
      if stat.isDirectory()
        return if ignoreDirectories.indexOf(basename file) >= 0
        fs.readdir file, (err, files) ->
          files.map((f) -> "#{file}/#{f}").forEach traverse
      else
        watch file

  traverse app_dir
  traverse config_dir

log 'Start'
registerHandlers()
startWorkers()
if do_watch
  startWatch()

process.on 'SIGHUP', ->
  destroyWorkers false
