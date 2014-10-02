path = require 'path'
{spawn} = require 'child_process'

process.env.PROJECT_ROOT = process.cwd()

task 'deploy', 'Deploys this app', ->
  command = __dirname + '/bin/deploy'
  args = []
  spawn command, args, stdio: 'inherit'

task 'start', 'Starts this app as daemon', ->
  command = __dirname + '/bin/start'
  args = []
  spawn command, args, stdio: 'inherit'

task 'stop', 'Stops the app daemon', ->
  command = __dirname + '/bin/stop'
  args = []
  spawn command, args, stdio: 'inherit'

task 'run', 'Runs the server', ->
  process.env.TZ = 'Etc/UTC'
  command = path.resolve require.resolve('coffee-script/register'), '../bin/coffee'
  args = [__dirname + '/lib/server.coffee', '-w', '-d']
  spawn command, args, stdio: 'inherit'

task 'run:test', 'Runs the test server', ->
  process.env.NODE_ENV = 'test'
  invoke 'run'
