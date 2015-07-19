View = require '../lib/view'
should = require 'should'
sinon = require 'sinon'

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
        view.element.matches "div"
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

      it.only "binds events for elements with event name attributes", ->
        sinon.stub view, 'viewClicked', (event, elt) ->
          event.type.should.equal 'keydown'
          elt.matches("div.rootDiv").should.true

        sinon.stub view, 'li1Clicked', (event, elt) ->
          event.type.should.equal 'click'
          elt.matches('li.foo').should.true

        sinon.stub view, 'li2Keypressed', (event, elt) ->
          event.type.should.equal 'keypress'
          elt.matches("li.bar").should.true

        view.element.dispatchEvent new MouseEvent('click')
        view.viewClicked.calledOnce.should.true

        view.li1.dispatchEvent new MouseEvent('click')
        view.li1Clicked.called.should.true
        view.li2Keypressed.called.should.false

        view.li1Clicked.reset()

        view.li2.dispatchEvent new KeyboardEvent('keypress')
        view.li2Keypressed.called.should.true
        view.li1Clicked.called.should.false

      it "makes the view object accessible via the ::view method on any child element", ->
        expect(view.view()).toBe view
        expect(view.header.view()).toBe view
        expect(view.subview.view()).toBe view.subview
        expect(view.subview.header.view()).toBe view.subview

      it "makes the view object accessible via the ::containingView method on child elements added after the fact", ->
        child = $('<div>')
        view.append(child)
        expect(child.view()).toBeUndefined()
        expect(child.containingView()).toBe view

      it "throws an exception if the view has more than one root element", ->
        class BadView extends View
          @content: ->
            @div id: 'one'
            @div id: 'two'

        expect(-> new BadView).toThrow("View markup must have a single root element")

      it "throws an exception if the view has no content", ->
        BadView = class extends View
          @content: -> # left blank intentionally

        expect(-> new BadView).toThrow("View markup must have a single root element")

      it "throws an exception if the view has a self closing tag with text", ->
        BadView = class extends View
          @content: ->
            @div =>
              @img 'text'

        expect(-> new BadView).toThrow("Self-closing tag img cannot have text or content")

    if document.registerElement?
      describe "when a view is attached/detached to/from the DOM", ->
        it "calls ::attached and ::detached hooks if present", ->
          content = $('#jasmine-content')
          view.attached = jasmine.createSpy('attached hook')
          view.detached = jasmine.createSpy('detached hook')
          content.append(view)
          expect(view.attached).toHaveBeenCalled()

          view.detach()
          expect(view.detached).toHaveBeenCalled()

    describe "when a view defines an ::afterAttach hook", ->
      it "throws an exception on construction", ->
        class BadView extends View
          @content: -> @div "Bad"
          afterAttach: ->

        expect(-> new BadView).toThrow()

    describe "when a view defines a ::beforeRemove hook", ->
      it "throws an exception on construction", ->
        class BadView extends View
          @content: -> @div "Bad"
          beforeRemove: ->

        expect(-> new BadView).toThrow()

    describe "when the view constructs a new jQuery wrapper", ->
      it "constructs instances of jQuery rather than the view class", ->
        expect(view.eq(0) instanceof jQuery).toBeTruthy()
        expect(view.eq(0) instanceof TestView).toBeFalsy()
        expect(view.end() instanceof jQuery).toBeTruthy()
        expect(view.end() instanceof TestView).toBeFalsy()

  describe "View.render (bound to $$)", ->
    it "renders a document fragment based on tag methods called by the given function", ->
      fragment = $$ ->
        @div class: "foo", =>
          @ol =>
            @li id: 'one'
            @li id: 'two'

      expect(fragment).toMatchSelector('div.foo')
      expect(fragment.find('ol')).toExist()
      expect(fragment.find('ol li#one')).toExist()
      expect(fragment.find('ol li#two')).toExist()

    it "renders subviews", ->
      fragment = $$ ->
        @div =>
          @subview 'foo', $$ ->
            @div id: "subview"

      expect(fragment.find('div#subview')).toExist()
      expect(fragment.foo).toMatchSelector('#subview')

  describe "$$$", ->
    it "returns the raw HTML constructed by tag methods called by the given function (not a jQuery wrapper)", ->
      html = $$$ ->
        @div class: "foo", =>
          @ol =>
            @li id: 'one'
            @li id: 'two'

      expect(typeof html).toBe 'string'
      fragment = $(html)
      expect(fragment).toMatchSelector('div.foo')
      expect(fragment.find('ol')).toExist()
      expect(fragment.find('ol li#one')).toExist()
      expect(fragment.find('ol li#two')).toExist()
