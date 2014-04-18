cluster = require 'cluster'
domain = require 'domain'
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

project_root = process.env.PWD or process.cwd()
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
  root = path.join process.env.HOME, '.croquis'
  try fs.mkdirSync root, '0755'
  logstream = fs.createWriteStream "#{root}/#{config.project}.log", flags: 'a+', mode: '0644', encoding: 'utf8'
  process.stdout.write = (chunk, encoding, cb) ->
    logstream.write chunk, encoding, cb
  process.stderr.write = (chunk, encoding, cb) ->
    logstream.write chunk, encoding, cb

log = (msg) ->
  console.log "[#{Date.now()}] [server] #{msg}"

debug = (msg) ->
#  console.log msg

registerHandlers = ->
  cluster.on 'exit', (worker, code, signal) ->
    if not worker.prevent_restart
      fork worker.exec, worker.graceful_exit

fork = (exec, graceful_exit) ->
  debug 'forking... ' + exec
  cluster.setupMaster()
  cluster.settings.exec = exec
  if redirect_log
    cluster.settings.silent = true
  worker = cluster.fork()
  worker.exec = exec
  worker.graceful_exit = graceful_exit
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
      for i in [0...numCPUs]
        fork app_dir + '/' + worker.app, worker.graceful_exit
    else
      fork app_dir + '/' + worker.app, worker.graceful_exit

destroyWorkers = (immediately) ->
  workers = []
  for id, worker of cluster.workers
    workers.push worker

  if immediately
    for worker in workers
      debug 'killing... ' + worker.exec
      worker.kill 'SIGHUP'
  else
    killOne = ->
      if workers.length > 0
        worker = workers.pop()
        worker.once 'disconnect', ->
          killOne()
        if worker.graceful_exit
          worker.prevent_restart = true
          fork worker.exec, worker.graceful_exit
          .once 'listening', ->
            debug 'killing... ' + worker.exec
            worker.kill 'SIGHUP'
        else
          debug 'killing... ' + worker.exec
          worker.kill 'SIGHUP'
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
