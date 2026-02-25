#!/usr/bin/env node

var debug = false

var isRestarting = false
var now = Math.floor(new Date() / 1000)
var onesecond = 1000

if (debug) {
  onesecond = 50;
}

// // Timeout after 30 minutes and restart
// setTimeout(function () {
//   console.log('RestartApp::Timeout exceeded, forcing a restart')
//   restart()
// }, timeout)

// No need to check for update... this was already done by update_check (?)
restart();
function restart () {
  if (debug) console.log('RestartApp::Restarting..')
  if (isRestarting) {
    if (debug) console.log("RestartApp::We're already restarting..")
    return
  }
  isRestarting = true

  var serverHostname = 'localhost'
  var serverPort = process.env.RUST_RCON_PORT
  var serverPassword = process.env.RUST_RCON_PASSWORD

  var WebSocket = require('ws')
  var ws = new WebSocket('ws://' + serverHostname + ':' + serverPort + '/' + serverPassword)
  ws.on('open', function open () {
    setTimeout(function () {
      console.log('Starting shutdown notice (5 minutes)');
      ws.send(createPacket("say NOTICE: We're updating the server in <color=orange>5 minutes</color>, so get to a safe spot!"))
      setTimeout(function () {
        ws.send(createPacket("say NOTICE: We're updating the server in <color=orange>4 minutes</color>, so get to a safe spot!"))
        setTimeout(function () {
          ws.send(createPacket("say NOTICE: We're updating the server in <color=orange>3 minutes</color>, so get to a safe spot!"))
          setTimeout(function () {
            ws.send(createPacket("say NOTICE: We're updating the server in <color=orange>2 minutes</color>, so get to a safe spot!"))
            setTimeout(function () {
              console.log('1 minute left before shutdown...');
              ws.send(createPacket("say NOTICE: We're updating the server in <color=orange>1 minute</color>, so get to a safe spot!"))
              setTimeout(function () {
                console.log('Kicking everyone and quitting now...');
                ws.send(createPacket('global.kickall <color=orange>Updating/Restarting</color>'))
                setTimeout(function () {
                  ws.send(createPacket('quit'))
                  setTimeout(function () {
                    ws.close(1000)
                    // After 2 minutes, if the server's still running, forcibly shut it down
                    setTimeout(function () {
                      var fs = require('fs')
                      fs.unlinkSync('/tmp/restart_app.lock')
                      console.log("Rust is not shutting down after 2 minutes. Killing RustDedicated...")
                      var childProcess = require('child_process')
                      childProcess.execSync('kill -s 2 $(pidof RustDedicated)')
                    }, onesecond * 60 * 2)
                  }, onesecond)
                }, onesecond)
              }, onesecond * 60)
            }, onesecond * 60)
          }, onesecond * 60)
        }, onesecond * 60)
      }, onesecond * 60)
    }, onesecond)
  })
}

function createPacket (command) {
  var packet =
  {
    Identifier: -1,
    Message: command,
    Name: 'WebRcon'
  }
  return JSON.stringify(packet)
}
