EventHandler = require './event_handler'
AtomShare    = require './atom_share'
WebSocket    = require 'ws'
NewSessionView = require './new-session-view'
SessionView = require './session-view'
CursorView = require './cursor-view'

module.exports =
  ### Public ###

  version: require('../package.json').version
  # The default remote pair settings
  # Internal: The default configuration properties for the package.
  config:
    serverAddress:
      title: 'Server address'
      type: 'string'
      default: 'motepair.herokuapp.com'
    serverPort:
      title: 'Server port number'
      type: 'integer'
      default: 80

  setDefaultValues: ->
    @address = atom.config.get('motepair.serverAddress')
    @portNumber = atom.config.get('motepair.serverPort')

  createSocketConnection: ->
    @setDefaultValues()
    new WebSocket("http://#{@address}:#{@portNumber}")

  activate: ->
    @setDefaultValues()
    atom.workspaceView.command "motepair:connect", => @startSession()
    atom.workspaceView.command "motepair:disconnect", => @deactivate()
    atom.workspaceView.command "motepair:cursor", => @cursor()

  cursor: ->
    editor = atom.workspace.activePaneItem
    cursor = new CursorView editor

  startSession: ->
    @view = new NewSessionView()
    @view.show()

    @view.on 'core:confirm', =>
      @connect(@view.miniEditor.getText())

  setupHeartbeat: ->
    id = setInterval =>
      @ws.send 'ping', (error) ->
        if error?
          clearInterval(id)
    , 30000

  connect: (sessionId)->

    @ws ?= @createSocketConnection()

    @ws.on "open", =>
      console.log("Connected")
      @setupHeartbeat()
      @atom_share = new AtomShare(@ws)
      @atom_share.start(sessionId)

      @event_handler = new EventHandler(@ws)
      @event_handler.listen()

      @event_handler.emitter.on 'socket-not-opened', =>
        @deactivate()

      @sessionStatusView = new SessionView
      @sessionStatusView.show(@view.miniEditor.getText())

    @ws.on 'error', (e) =>
      console.log('error', e)
      @ws.close()
      @ws = null


  deactivate: ->
    @sessionStatusView?.hide()
    @ws?.close()
    @ws = null
    @event_handler?.subscriptions.dispose()
    @atom_share?.subscriptions.dispose()
