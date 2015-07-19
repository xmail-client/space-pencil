should = require 'should'

should.Assertion.add 'matchMarkup', (val, description) ->
  expectedMarkup = val.replace(/\n\s*/g, '')
  this.params =
    operator: ' to match markup'
    expected: expectedMarkup
    message: description
  actualMarkup = this.obj.outerHTML
  this.assert actualMarkup is expectedMarkup
