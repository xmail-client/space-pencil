View = require '../lib/view'

describe "Builder", ->
  it "builds an DOM elements based on the given function", ->
    [html, postProcessingSteps] = View.buildHtml ->
      @div class: "greeting", =>
        @h1 =>
          @text "Hello"
          @span "World"
    element = View.buildDOMFromHTML(html, postProcessingSteps)
    element.should.matchMarkup """
      <div class="greeting">
        <h1>Hello<span>World</span></h1>
      </div>
    """
