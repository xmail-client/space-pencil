# Space Pencil

This library currently has an element builder with the same
DSL as [SpacePen](https://github.com/atom/space-pen), but it returns a raw DOM element rather than a jQuery fragment.

```coffee
View = require 'space-pencil'

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
```

## Write markup on the final frontier

SpacePencil is a powerful but minimalistic client-side view framework for
CoffeeScript. It combines the "view" and "controller" into a single object,
whose markup is expressed with an embedded DSL similar to Markaby for Ruby.

The `space-pencil` API is like `space-pen` but remove the `jQuery` integration.

## API

The `View` class has the following instance methods.

  * **find**: `function(selector)`

    Find the child nodes in the element tree by css selector.

  * **findAll**: `function(selector)`

    Find all of the child nodes by css selector.

  * **on**: `function(eventName, callback)`

    Add event listener `callback` for the `eventName` event.

  * **off**: `function(eventName, callback)`

    Remove event listener `callback` for the `eventName` event.

  * **once**: `function(eventName, callback)`

    Add event listener just like `on`, but after the event has trigger, the event
    callback will remove automatically.

Also, `View` has many html builder static method, such as `div`, `image`.
Otherwise the HTML tag method, the following static method is included.

  * **text**: `function(string)`

    Build the text node. The particular character will escaped.

  * **raw**: `function(string)`

    Build the text node and the text will retain.

  * **tag**: `function(tagName, args...)`

    Build the `tagName` tag node.

  * **subview**: `function(name, view)`

    Integrate the sub view into this view.

## Basics

View objects extend from the View class and have a @content class method where
you express their HTML contents with an embedded markup DSL:

```coffeescript
class Spacecraft extends View
  @content: ->
    @div =>
      @h1 "Spacecraft"
      @ol =>
        @li "Apollo"
        @li "Soyuz"
        @li "Space Shuttle"
```

You can visit the view's DOM element by `view.element`.

```coffeescript
view = new Spacecraft
view.find('ol').appendChild View.buildDOMFromHTML('<li>Star Destroyer</li>')

view.on 'click', ->
  alert "They clicked on #{$(this).text()}"
```

You can also pass arguments on construction, which get passed to both the
`@content` method and the view's constructor.

```coffeescript
class Spacecraft extends View
  @content: (params) ->
    @div =>
      @h1 params.title
      @ol =>
        @li name for name in params.spacecraft

view = new Spacecraft(title: "Space Weapons", spacecraft: ["TIE Fighter", "Death Star", "Warbird"])
```

If you override the View class's constructor, ensure you call `super`.
Alternatively, you can define an `initialize` method, which the constructor will
call for you automatically with the constructor's arguments.

```coffeescript
class Spacecraft extends View
  @content: -> ...

  initialize: (params) ->
    @title = params.title
```

## Outlets and Events

SpacePencil will automatically create named reference for any element with an
`outlet` attribute. For example, if the `ol` element has an attribute
`outlet=list`, the view object will have a `list` entry pointing to a jQuery
wrapper for the `ol` element.

```coffeescript
class Spacecraft extends View
  @content: ->
    @div =>
      @h1 "Spacecraft"
      @ol outlet: "list", =>
        @li "Apollo"
        @li "Soyuz"
        @li "Space Shuttle"

  addSpacecraft: (name) ->
    @list.appendChild View.buildDOMFromHTML("<li>#{name}</li>")
```

Elements can also have event name attributes whose value references a custom
method. For example, if a `button` element has an attribute
`click=launchSpacecraft`, then SpacePen will invoke the `launchSpacecraft`
method on the button's parent view when it is clicked:

```coffeescript
class Spacecraft extends View
  @content: ->
    @div =>
      @h1 "Spacecraft"
      @ol =>
        @li click: 'launchSpacecraft', "Saturn V"

  launchSpacecraft: (event, element) ->
    console.log "Preparing #{element.name} for launch!"
```
## Markup DSL Details

### Tag Methods (`@div`, `@h1`, etc.)

As you've seen so far, the markup DSL is pretty straightforward. From the
`@content` class method or any method it calls, just invoke instance methods
named for the HTML tags you want to generate. There are 3 types of arguments you
can pass to a tag method:

* *Strings*: The string will be HTML-escaped and used as the text contents of the generated tag.

* *Hashes*: The key-value pairs will be used as the attributes of the generated tag.

* *Functions* (bound with `=>`): The function will be invoked in-between the open and closing tag to produce the HTML element's contents.

If you need to emit a non-standard tag, you can use the `@tag(name, args...)`
method to name the tag with a string:

```coffeescript
@tag 'bubble', type: "speech", => ...
```

### Text Methods

* `@text(string)`: Emits the HTML-escaped string as text wherever it is called.

* `@raw(string)`: Passes the given string through unescaped. Use this when you need to emit markup directly that was generated beforehand.

## Subviews

Subviews are a great way to make your view code more modular. The
`@subview(name, view)` method takes a name and another view object. The view
object will be inserted at the location of the call, and a reference with the
given name will be wired to it from the parent view. A `parentView` reference
will be created on the subview pointing at the parent.

```coffeescript
class Spacecraft extends View
  @content: (params) ->
    @div =>
      @subview 'launchController', new LaunchController(countdown: params.countdown)
      @h1 "Spacecraft"
      ...
```

## Freeform Markup Generation

You don't need a View class to use the SpacePen markup DSL. Call `View.render`
with an unbound function (`->`, not `=>`) that calls tag methods, and it will
return a document fragment for ad-hoc use. This method is also assigned to the
`$$` global variable for convenience.

```coffeescript
view.list.append $$ ->
  @li =>
    @text "Starship"
    @em "Enterprise"
```
