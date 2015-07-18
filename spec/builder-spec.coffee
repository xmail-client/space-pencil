Builder = require '../lib/builder'

describe "Builder", ->
  it "builds an DOM elements based on the given function", ->
    builder = new Builder
    element = builder.buildElement ->
      @div class: "greeting", ->
        @h1 ->
          @text "Hello"
          @span "World"

    element.should.matchMarkup """
      <div class="greeting">
        <h1>Hello<span>World</span></h1>
      </div>
    """
