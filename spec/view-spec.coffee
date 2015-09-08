View = require '../lib/space-view'
should = require 'should'
sinon = require 'sinon'

afterEach ->
  View.builderStack = null

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

describe "View", ->
  view = null

  describe "View objects", ->
    TestView = null

    beforeEach ->
      class Subview extends View
        @content: (params={}, otherArg) ->
          @div =>
            @h2 { outlet: "header" }, params.title + " " + otherArg
            @div "I am a subview"
            @tag 'mytag', id: 'thetag', 'Non standard tag'

        initialize: (args...) ->
          @initializeCalledWith = args

      class TestView extends View
        @content: (params={}, otherArg) ->
          @div keydown: 'viewClicked', class: 'rootDiv', =>
            @h1 { outlet: 'header' }, params.title + " " + otherArg
            @list()
            @subview 'subview', new Subview(title: "Subview", 43)

        @list: ->
          @ol =>
            @li outlet: 'li1', click: 'li1Clicked', class: 'foo', "one"
            @li outlet: 'li2', keypress:'li2Keypressed', class: 'bar', "two"

        initialize: (args...) ->
          @initializeCalledWith = args

        foo: "bar",
        li1Clicked: ->,
        li2Keypressed: ->
        viewClicked: ->

      view = new TestView({title: "Zebra"}, 42)

    describe "constructor", ->
      it "calls the content class method with the given params to produce the view's html", ->
        view.root.matches "div"
        view.find("h1").textContent.should.equal 'Zebra 42'
        view.find("mytag#thetag").textContent.should.equal 'Non standard tag'
        view.find("ol > li.foo").textContent.should.equal 'one'
        view.find("ol > li.bar").textContent.should.equal 'two'

      it "calls initialize on the view with the given params", ->
        view.initializeCalledWith.should.eql([{title: "Zebra"}, 42])

      it "wires outlet referenecs to elements with 'outlet' attributes", ->
        view.li1.matches("li.foo").should.true
        view.li2.matches("li.bar").should.true

      it "removes the outlet attribute from markup", ->
        view.li1.hasAttribute('outlet').should.false
        view.li2.hasAttribute('outlet').should.false

      it "constructs and wires outlets for subviews", ->
        view.subview.should.true
        view.subview.find('h2').should.true
        view.subview.parentView.should.equal view
        should.not.exist(view.subview.constructor.currentBuilder)
        view.subview.initializeCalledWith.should.eql [{title: "Subview"}, 43]

      it "does not overwrite outlets on the superview with outlets from the subviews", ->
        view.header.matches('h1').should.true
        view.subview.header.matches('h2').should.true

      it "binds events for elements with event name attributes", ->
        sinon.stub view, 'viewClicked', (event, elt) ->
          event.type.should.equal 'keydown'
          elt.matches("div.rootDiv").should.true

        sinon.stub view, 'li1Clicked', (event, elt) ->
          event.type.should.equal 'click'
          elt.matches('li.foo').should.true

        sinon.stub view, 'li2Keypressed', (event, elt) ->
          event.type.should.equal 'keypress'
          elt.matches("li.bar").should.true

        view.root.dispatchEvent new MouseEvent('click')
        view.viewClicked.calledOnce.should.true

        view.li1.dispatchEvent new MouseEvent('click')
        view.li1Clicked.called.should.true
        view.li2Keypressed.called.should.false

        view.li1Clicked.reset()

        view.li2.dispatchEvent new KeyboardEvent('keypress')
        view.li2Keypressed.called.should.true
        view.li1Clicked.called.should.false

      it "makes the view object accessible via the ::view method on any child element", ->
        view.root.spaceView.should.equal view
        view.header.spaceView.should.equal view
        view.subview.root.spaceView.should.equal view.subview
        view.subview.header.spaceView.should.equal view.subview

      it "throws an exception if the view has more than one root element", ->
        class BadView extends View
          @content: ->
            @div id: 'one'
            @div id: 'two'

        (-> new BadView).should.throw("View markup must have a single root element")

      it "throws an exception if the view has no content", ->
        BadView = class extends View
          @content: -> # left blank intentionally

        (-> new BadView).should.throw("View markup must have a single root element")

      it "throws an exception if the view has a self closing tag with text", ->
        BadView = class extends View
          @content: ->
            @div =>
              @img 'text'

        (-> new BadView).should.throw("Self-closing tag img cannot have text or content")

      it "trigger the event callback if listen on event", ->
        callback = sinon.spy()
        view.on 'click', callback
        view.root.dispatchEvent new MouseEvent('click')
        callback.called.should.true
        callback.reset()

        view.off 'click', callback
        view.root.dispatchEvent new MouseEvent('click')
        callback.called.should.false
        callback.reset()

        view.once 'click', callback
        view.root.dispatchEvent new MouseEvent('click')
        callback.called.should.true
        view.root.dispatchEvent new MouseEvent('click')
        callback.calledOnce.should.true

    if document.registerElement?
      describe "when a view is attached/detached to/from the DOM", ->
        it "calls ::attached and ::detached hooks if present", ->
          content = document.createElement('div');
          view.attached = sinon.spy()
          view.detached = sinon.spy()
          content.appendChild(view.root)
          view.attached.called.should.true

          view.remove()
          view.detached.called.should.true

  describe "View.render", ->
    it "renders a document fragment based on tag methods called by the given function", ->
      fragment = View.render ->
        @div class: "foo", =>
          @ol =>
            @li id: 'one'
            @li id: 'two'

      fragment.matches('div.foo').should.true
      fragment.querySelector('ol').should.exist
      fragment.querySelector('ol li#one').should.exist
      fragment.querySelector('ol li#two').should.exist

    it "renders subviews", ->
      fragment = View.render ->
        @div =>
          @subview 'foo', View.render ->
            @div id: "subview"

      fragment.querySelector('div#subview').should.exist
      fragment.foo.matches('#subview').should.exist

  describe "View.renderHtml", ->
    it "returns the raw HTML constructed by tag methods called by the given function", ->
      html = View.renderHtml ->
        @div class: "foo", =>
          @ol =>
            @li id: 'one'
            @li id: 'two'

      (typeof html).should.equal 'string'
      fragment = View.buildDOMFromHTML(html)
      fragment.matches('div.foo').should.true
      fragment.querySelector('ol').should.exist
      fragment.querySelector('ol li#one').should.exist
      fragment.querySelector('ol li#two').should.exist
