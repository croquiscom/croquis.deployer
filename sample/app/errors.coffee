CroquisError = (code, table) ->
  @message = table.message
  @_code = code
  @_table = table
  return
require('util').inherits CroquisError, Error

errors = CroquisError: CroquisError

module.exports = errors
