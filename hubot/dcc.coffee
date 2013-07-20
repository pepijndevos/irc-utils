# Description:
#   DCC SEND and passive DCC SEND module
#
# Configuration:
#   HUBOT_WEBADDR - the http address
#   HUBOT_HOST - the ip in decimal form
#
# Commands:
#   hubot recent files - List the 5 most recent files.

net = require 'net'
fs = require 'fs'
path = require 'path'
buf = require 'buffer'

WEBADDR = process.env.HUBOT_WEBADDR || "http://127.0.0.1:8080/"
HOST = process.env.HUBOT_HOST || 2130706433
DIRNAME = path.resolve("data")

intToIP = (n) ->
  byte1 = n & 255
  byte2 = ((n >> 8) & 255)
  byte3 = ((n >> 16) & 255)
  byte4 = ((n >> 24) & 255)
  byte4 + "." + byte3 + "." + byte2 + "." + byte1

safePath = (name) ->
  fname = path.resolve(DIRNAME, name)
  fname.indexOf(DIRNAME) == 0 && fname

saveData = (filename, data) ->
  fs.appendFile filename, data, (err) =>
    if err
      this.end()
      console.warn(err)
    else
      ack = new buf.Buffer(4)
      ack.writeUInt32BE(this.bytesRead, 0)
      this.write(ack)

listen = (filename) ->
  server = net.createServer()
  server.on("error", (err) -> console.warn(err))
  server.listen(0);
  
  server.on "connection", (conn) ->
    conn.on("data", saveData.bind(conn, filename))
    conn.on("close", -> server.close())
    conn.on("error", (err) -> console.warn(err))

  server.address()['port']

download = (host, port, filename) ->
  client = new net.Socket()
  client.connect(port, host)
  client.on("data", saveData.bind(client, filename))
  client.on("error", (err) -> console.warn(err))

parse = (msg) ->
  if msg.lastIndexOf("DCC SEND", 0) == 0
    [_dcc, _send, filename, ip, port, filesize, token] = msg.split(' ')

    filename: filename,
    ip: intToIP(parseInt(ip)),
    port: parseInt(port),
    filesize: parseInt(filesize),
    token: parseInt(token)

recentFiles = (msg) ->
  fs.readdir DIRNAME, (err, files) ->
    files.sort (a, b) ->
      at = fs.statSync(path.resolve(DIRNAME, a)).mtime.getTime()
      bt = fs.statSync(path.resolve(DIRNAME, b)).mtime.getTime()
      bt - at
    for f in files[0..4]
      msg.send(WEBADDR + f)

module.exports = (robot) ->
  robot.respond(/recent files/i, recentFiles)
  robot.adapter.bot.addListener "ctcp-privmsg", (from, to, text) ->
    info = parse(text)
    console.log(info)
    filename = safePath(info.filename)
    if filename
      fs.unlink(filename, -> "whatevs")
      if info.port == 0
        port = listen(filename)
        robot.adapter.bot.ctcp(from, "privmsg", "DCC SEND #{info.filename} #{HOST} #{port} #{info.filesize} #{info.token}")
      else
        download(info.ip, info.port, filename)
