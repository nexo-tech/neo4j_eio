val connect_and_handshake :
  sw:Eio.Switch.t -> net:_ Eio.Net.t -> Config.t -> (Protocol.version, Error.t) result
