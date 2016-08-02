cluster = require 'cluster'
domain = require 'domain'
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

project_root = process.env.PROJECT_ROOT
if /versions\/\d{4}-\d{2}-\d{2},\d{2}-\d{2},[a-z0-9]{7}$/.test project_root
  project_root = path.resolve project_root, '..', '..', 'current'
project_root = path.relative process.cwd(), project_root
if not project_root
  project_root = '.'

app_dir = project_root + '/app'
config_dir = project_root + '/config'

shutdowning = false

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
  console.log "[#{Date.now()}] [deployer] #{msg}"

debug = (msg) ->
#  console.log msg

registerHandlers = ->
  cluster.on 'exit', (worker, code, signal) ->
    if shutdowning
      if Object.keys(cluster.workers).length is 0
        console.log "[#{Date.now()}] [deployer] Terminate"
        process.exit 0
      return
    if not worker.prevent_restart
      options = worker.options
      if options.try < 3
        fork options

fork = (options) ->
  log 'forking... ' + options.exec
  options.try++
  cluster.setupMaster()
  cluster.settings.exec = __dirname + '/run_app.coffee'
  cluster.settings.args = [project_root, options.exec]
  if redirect_log
    cluster.settings.silent = true
  worker = cluster.fork WORKER_NUM: options.num
  worker.options = options
  if redirect_log
    worker.process.stdout.on 'data', (data) ->
      logstream.write data
    worker.process.stderr.on 'data', (data) ->
      logstream.write data
  worker.once 'listening', -> worker.options.try = 0
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
      fork exec: app_dir + '/' + worker.app, num: i, graceful_exit: worker.graceful_exit, try: 0

destroyWorkers = ->
  workers = []
  for id, worker of cluster.workers
    workers.push worker

  killOne = ->
    if workers.length > 0
      worker = workers.pop()
      worker.once 'disconnect', ->
        killOne()
      worker.options.try = 0
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
          destroyWorkers()

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

log "Start at #{fs.realpathSync project_root}"
registerHandlers()
startWorkers()
if do_watch
  startWatch()

process.on 'SIGHUP', ->
  log "Restart at #{fs.realpathSync project_root}"
  destroyWorkers()
process.on 'SIGINT', ->
  shutdowning = true
