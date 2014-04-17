var path = require('path');
var spawn = require('child_process').spawn;

task('deploy', 'Deploys this app', function() {
  var command = __dirname + '/bin/deploy';
  var args = [];
  spawn(command, args, { stdio: 'inherit' });
});

task('start', 'Starts this app as daemon', function() {
  var command = __dirname + '/bin/start';
  var args = [];
  spawn(command, args, { stdio: 'inherit' });
});

task('stop', 'Stops the app daemon', function() {
  var command = __dirname + '/bin/stop';
  var args = [];
  spawn(command, args, { stdio: 'inherit' });
});

task('run', 'Runs the server', function () {
  var command = path.resolve(require.resolve('coffee-script/register'), '../bin/coffee');
  var args = [__dirname + '/lib/server.coffee', '-w', '-d'];
  spawn(command, args, { stdio: 'inherit' });
});

task('run:test', 'Runs the test server', function () {
  process.env.NODE_ENV = 'test';
  invoke('run');
});
