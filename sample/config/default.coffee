path = require 'path'

module.exports =
  project_root: path.resolve __dirname, '..'

  app_title: 'Sample'

  redis_port: 6379

  log4js_config:
    appenders: [ {
      type: 'console'
    } ]
    replaceConsole: false

  session_ttl: 86400
  session_secret: 'sample'
