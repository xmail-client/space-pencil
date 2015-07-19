Tags =
  'a abbr address article aside audio b bdi bdo blockquote body button canvas
   caption cite code colgroup datalist dd del details dfn dialog div dl dt em
   fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 head header html i
   iframe ins kbd label legend li main map mark menu meter nav noscript object
   ol optgroup option output p pre progress q rp rt ruby s samp script section
   select small span strong style sub summary sup table tbody td textarea tfoot
   th thead time title tr u ul var video area base br col command embed hr img
   input keygen link meta param source track wbr'.split /\s+/

SelfClosingTags = {}
'area base br col command embed hr img input keygen link meta param
 source track wbr'.split(/\s+/).forEach (tag) -> SelfClosingTags[tag] = true

Events =
  'blur change click dblclick error focus input keydown
   keypress keyup load mousedown mousemove mouseout mouseover
   mouseup resize scroll select submit unload'.split /\s+/

# Public: View class that extends the jQuery prototype.
#
# Extending classes must implement a `@content` method.
#
# ## Examples
#
# ```coffee
# class Spacecraft extends View
#   @content: ->
#     @div =>
#       @h1 'Spacecraft'
#       @ol =>
#         @li 'Apollo'
#         @li 'Soyuz'
#         @li 'Space Shuttle'
# ```
#
# Each view instance will have all the methods from the jQuery prototype
# available on it.
#
# ```coffee
#   craft = new Spacecraft()
#   craft.find('h1').text() # 'Spacecraft'
#   craft.appendTo(document.body) # View is now a child of the <body> tag
# ```
module.exports =
class View
  @builderStack: null

  Tags.forEach (tagName) ->
    View[tagName] = (args...) -> @currentBuilder.tag(tagName, args...)

  # Public: Add the given subview wired to an outlet with the given name
  #
  # * `name` {String} name of the subview
  # * `view` DOM element or jQuery node subview
  @subview: (name, view) ->
    @currentBuilder.subview(name, view)

  # Public: Add a text node with the given text content
  #
  # * `string` {String} text contents of the node
  @text: (string) -> @currentBuilder.text(string)

  # Public: Add a new tag with the given name
  #
  # * `tagName` {String} name of the tag like 'li', etc
  # * `args...` other arguments
  @tag: (tagName, args...) -> @currentBuilder.tag(tagName, args...)

  # Public: Add new child DOM nodes from the given raw HTML string.
  #
  # * `string` {String} HTML content
  @raw: (string) -> @currentBuilder.raw(string)

  @pushBuilder: ->
    builder = new Builder
    @builderStack ?= []
    @builderStack.push(builder)
    @currentBuilder = builder

  @popBuilder: ->
    @currentBuilder = @builderStack[@builderStack.length - 2]
    @builderStack.pop()

  @buildHtml: (fn) ->
    @pushBuilder()
    fn.call(this)
    [html, postProcessingSteps] = @popBuilder().buildHtml()

  @buildDOMFromHTML: (html, postProcessingSteps) ->
    div = document.createElement('div')
    div.innerHTML = html
    if div.childElementCount isnt 1
      throw new Error("View markup must have a single root element")
    fragment = div.firstElementChild
    step(fragment) for step in postProcessingSteps
    fragment

  @render: (fn) ->
    [html, postProcessingSteps] = @buildHtml(fn)
    @buildDOMFromHTML(html, postProcessingSteps)

  constructor: (args...) ->
    [html, postProcessingSteps] = @constructor.buildHtml -> @content(args...)
    @element = @buildDOMFromHTML(html, postProcessingSteps)
    @element.attached = => @attached?()
    @element.detached = => @detached?()

    @wireOutlets(this)
    @bindEventHandlers(this)

    @element.spacePenView = this
    treeWalker = document.createTreeWalker(@element, NodeFilter.SHOW_ELEMENT)
    while element = treeWalker.nextNode()
      element.spacePenView = this

    if postProcessingSteps?
      step(@element) for step in postProcessingSteps
    @initialize?(args...)

  buildHtml: (params) ->
    @constructor.builder = new Builder
    @constructor.content(params)
    [html, postProcessingSteps] = @constructor.builder.buildHtml()
    @constructor.builder = null
    postProcessingSteps

  wireOutlets: (view) ->
    root = view.element
    for element in root.querySelectorAll('[outlet]')
      outlet = element.getAttribute('outlet')
      view[outlet] = element
      element.removeAttribute('outlet')

    undefined

  bindEventHandlers: (view) ->
    root = view.element
    for eventName in Events
      selector = "[#{eventName}]"
      for element in element.querySelectorAll(selector)
        do (element) ->
          methodName = element.getAttribute(eventName)
          element.on eventName, (event) -> view[methodName](event, element)

      if matchesSelector(view, selector)
        methodName = view[0].getAttribute(eventName)
        do (methodName) ->
          view.on eventName, (event) -> view[methodName](event, view)

    undefined

class Builder
  for tagName in TagNames
    do (tagName) => @::[tagName] = (args...) -> @tag(tagName, args...)

  constructor: ->
    @document = []
    @postProcessingSteps = []

  buildElement: (fn) ->
    wrapper = document.createElement('div')
    wrapper.innerHTML = @buildHtml(fn)
    wrapper.firstChild

  buildHtml: (fn) ->
    [@document.join(''), @postProcessingSteps]

  tag: (name, args...) ->
    for arg in args
      switch typeof arg
        when 'function' then content = arg
        when 'string', 'number' then text = arg.toString()
        when 'object' then attributes = arg

    @openTag(name, attributes)

    if SelfClosingTags.hasOwnProperty(name)
      if text? or content?
        throw new Error("Self-closing tag #{name} cannot have text or content")
    else
      content.call(this) if content?
      @text(text) if text?
      @closeTag(name)

  openTag: (name, attributes) ->
    attributePairs =
      for attributeName, value of attributes
        "#{attributeName}=\"#{value}\""

    attributesText =
      if attributePairs.length
        " " + attributePairs.join(" ")
      else
        ""

    @document.push("<#{name}#{attributesText}>")

  closeTag: (name) ->
    @document.push("</#{name}>")

  text: (text) ->
    escapeMap =
      '&': '&amp;'
      '"': '&quot;'
      '\'': '&#39;'
      '<': '&lt;'
      '>': '&gt;'
    escapedText = text.replace /&|"|'|<|>/g, (match) -> escapeMap[match]
    @document.push(escapedText)

  raw: (text) ->
    @document.push(text)

  idCounter = 0

  subview: (outletName, subview) ->
    subviewId = "subview-#{++idCounter}"
    @tag 'div', id: subviewId
    @postProcessingSteps.push (view) ->
      view[outletName] = subview
      subview.parentView = view
      view.find("div##{subviewId}").replaceWith(subview)
