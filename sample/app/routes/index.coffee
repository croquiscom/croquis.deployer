worker_num = process.env.WORKER_NUM
CONFIG = require 'config'
errors = require '../errors'

routes_root = (router) ->
  console.log "[#{Date.now()}] [server#{worker_num}] Init routes" if worker_num

  router.get '/ping', (req, res) ->
    res.sendResult 'pong'

module.exports =
  '': routes_root
