#!/usr/bin/env node

const readline = require("readline");

var debug = false;
var exitcode=1;
var argumentString = ''
var interractive_session=undefined;
var args = process.argv.splice(process.execArgv.length + 2)
if(args[0] == '-it'){
  console.log("Running interactively (ctrl+c to exit)");

  interractive_session = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  interractive_session.on("close", function() {
    process.exit(0);
  });
}
else{
  for (var i = 0; i < args.length; i++) {
    if (i === args.length - 1) argumentString += args[i]
    else argumentString += args[i] + ' '
  }

  if (argumentString.length < 1) {
    console.log('RconApp::Error: Please specify an RCON command or -it for an interractive session')
    process.exit(exitcode)
  }
}

if(debug)
  console.log('RconApp::Relaying RCON command: ' + argumentString)

var serverHostname = 'localhost'
var serverPort = process.env.RUST_RCON_PORT
var serverPassword = process.env.RUST_RCON_PASSWORD

var ourselves=Math.floor(Math.random()*(100000));

if(debug)
  console.log("We have identifier",ourselves);
var messageSent = false
var WebSocket = require('ws')
var ws = new WebSocket('ws://' + serverHostname + ':' + serverPort + '/' + serverPassword)
ws.on('open', function open () {
    messageSent = true
    if(interractive_session){
      onUserInput(0);
    }
    else{
      ws.send(createPacket(argumentString))
      setTimeout(function () {
        ws.close()
        console.log("RconApp::Error: no response (perhaps the command is invalid?)");
        process.exit(exitcode)
      }, 1000)
  
    }
})

function onUserInput(input){
  if(input)
    ws.send(createPacket(input))
  interractive_session.question("",  onUserInput);
}

ws.on('message', function (data, flags) {
  if (!messageSent) return
  try {
    var json = JSON.parse(data)
    if(debug)
      console.log("Message:",json);
    if (json !== undefined) {
      if (json.Message !== undefined && json.Message.length > 0
          && json.Identifier == ourselves) {
        console.log(json.Message);
        if(!interractive_session){
          setTimeout(function() {
            exitcode=0;
            ws.close();
            ws.terminate();
          },25);
        }
      }
    } else console.log('RconApp::Error: Invalid JSON received')
  } catch (e) {
    if (e) console.log('RconApp::Error:', e)
  }
})

ws.on('close', function () {
  process.exit(exitcode)
});

ws.on('error', function (e) {
  console.log('RconApp::Error:', e)
  console.log('Perhaps rust is not up yet or the password is not set?')
  process.exit(exitcode)
})

function createPacket (command) {
  var packet =
  {
    Identifier: ourselves,
    Message: command,
    Name: 'WebRcon'
  }
  return JSON.stringify(packet)
}
