worker_num = Number(process.env.WORKER_NUM) or 0
process.env.NODE_CONFIG_DIR = __dirname + '/../config'

CONFIG = require 'config'
crary = require '@croquiscom/crary'
http = require 'http'

app = crary.express.createApp
  project_root: CONFIG.project_root
  log4js_config: CONFIG.log4js_config
  redis_port: CONFIG.redis_port
  session_ttl: CONFIG.session_ttl
  session_secret: CONFIG.session_secret
  errors: require './errors'
  routers: require './routes'
server = http.createServer app

port = if worker_num is 9999 then 9999 else 3000
server.listen port, ->
  console.log "[#{Date.now()}] [server#{worker_num}] Started"

_shutdowning = false
shutdown = ->
  if _shutdowning
    return
  console.log "[#{Date.now()}] [server#{worker_num}] Shutdown"
  _shutdowning = true

  # 5초간 끝나지 않으면 강제 종료
  setTimeout ->
    process.exit 0
  , 5000

  server.close ->
    console.log "[#{Date.now()}] [server#{worker_num}] Terminate"
    process.exit 0

process.on 'SIGHUP', shutdown
process.on 'SIGTERM', shutdown
process.on 'SIGINT', shutdown
