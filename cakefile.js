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
