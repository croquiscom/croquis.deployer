path = require 'path'
{spawn} = require 'child_process'

process.env.PROJECT_ROOT = process.cwd()
process.env.TZ = 'Etc/UTC'

task 'deploy', 'Deploys this app', ->
  command = __dirname + '/bin/deploy'
  args = []
  spawn command, args, stdio: 'inherit'

task 'start', 'Starts this app as daemon', ->
  command = __dirname + '/bin/start'
  args = []
  child = spawn command, args, stdio: 'inherit'
  child.on 'exit', (code) ->
    process.exit code

task 'stop', 'Stops the app daemon', ->
  command = __dirname + '/bin/stop'
  args = []
  spawn command, args, stdio: 'inherit'

task 'logrotate', 'Rotates the log', ->
  command = __dirname + '/bin/send_signal'
  args = ['SIGUSR2']
  spawn command, args, stdio: 'inherit'

task 'run', 'Runs the server', ->
  command = path.resolve require.resolve('coffee-script/register'), '../bin/coffee'
  args = [__dirname + '/lib/server.coffee', '-w', '-d']
  child = spawn command, args, stdio: 'inherit'
  process.on 'SIGTERM', ->
    child.kill 'SIGTERM'

task 'run:test', 'Runs the test server', ->
  process.env.NODE_ENV = 'test'
  invoke 'run'
