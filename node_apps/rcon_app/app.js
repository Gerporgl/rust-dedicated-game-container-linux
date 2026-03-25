#!/usr/bin/env node

process.title = "rcon"

const readline = require("readline");
const parseArgs = require("node:util").parseArgs;
const MAX_CUSTOM_MSG = 1
const CUSTOM_CHAT_TAIL = 1

const { values, positionals } = parseArgs({
    options: {
        interactive: {
            type: 'boolean',
            short: 'i',
            default: false,
        },
        filter: {
            type: 'string',
            short: 'f',
            default: [],
            multiple: true,
        },
        timeout: {
          type: 'string',
          short: 't',
          default: '1000',
        },
        silent: {
          type: 'boolean',
          short: 's',
          default: false,
        },
        debug: {
          type: 'boolean',
          short: 'd',
          default: false,
        },
    },
    allowPositionals: true,
    strict: false,
});

var debug = values.debug;

if(debug){
  console.log('Values:', values);
  console.log('Positionals:', positionals);
}

var timeout= parseInt(values.timeout);
if(isNaN(timeout))
  timeout=1000;
var exitcode=1;
var argumentString = ''
var interactive_session=undefined;

var ourselves=Math.floor(Math.random()*(100000));
var alltypes =  [];

if(values.interactive || (values.filter != undefined && values.filter.length > 0)){
  if(values.interactive)
    console.log("Running \x1b[1;32minteractively\x1b[0m (ctrl+c to exit)");
  else
  {
    alltypes = values.filter;
    console.log(`Running in live interactive view with Type filter: \x1b[1;32m${alltypes}\x1b[0m (ctrl+c to exit)`);
  }

  interactive_session = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  interactive_session.on("close", function() {
    process.exit(0);
  });
}
else
{
  for (var i = 0; i < positionals.length; i++) {
    if (i === positionals.length - 1) argumentString += positionals[i]
    else argumentString += positionals[i] + ' '
  }

  if (argumentString.length < 1) {
    console.log('RconApp::Error: Please specify an RCON command or -i for an interactive session or --filter to force an interactive session with type filters')
    process.exit(exitcode)
  }
}

if(debug)
  console.log('RconApp::Relaying RCON command: ' + argumentString)

var serverHostname = 'localhost'
var serverPort = process.env.RUST_RCON_PORT
var serverPassword = process.env.RUST_RCON_PASSWORD


if(debug)
  console.log("We have identifier",ourselves);
var messageSent = false
var WebSocket = require('ws')
var ws = new WebSocket('ws://' + serverHostname + ':' + serverPort + '/' + serverPassword)
ws.on('open', function open () {
    messageSent = true
    if(interactive_session){
      if( alltypes.includes('chat'))
        ws.send(createPacket('chat.tail', CUSTOM_CHAT_TAIL));
      onUserInput(0);
    }
    else{
      ws.send(createPacket(argumentString))
      setTimeout(function () {
        ws.close()
        if(!values.silent)
          console.log("RconApp::Error: no response (perhaps the command is invalid?)");
        process.exit(exitcode)
      }, timeout)
 
    }
})

function onUserInput(input){
  if(input)
  {
    if (input.toLowerCase() == "chat.tail")
      ws.send(createPacket(input, CUSTOM_CHAT_TAIL))
    else
      ws.send(createPacket(input))
  }
  interactive_session.question("",  onUserInput);
}

function print_chat(chatMsg){
  console.log(`${chatMsg.Channel == 0 ? '\x1b[1;33m[GLOBAL]\x1b[0m' : '\x1b[1;32m[TEAM]\x1b[0m'} \x1b[1;34m${chatMsg.Username}\x1b[0m: ${chatMsg.Message}`);
}

ws.on('message', function (data, flags) {
  if (!messageSent) return
  try {
    var json = JSON.parse(data)
    if(debug)
      console.log("Message:",json);
    if (json !== undefined) {
      if (json.Message !== undefined && json.Message.length > 0
          && ((json.Identifier >= ourselves && json.Identifier <= ourselves+MAX_CUSTOM_MSG) || (alltypes.includes(json.Type.toLowerCase() ) || (alltypes.includes('any')) ))) {
        if(json.Type == 'Chat' || json.Identifier == ourselves + CUSTOM_CHAT_TAIL){
          var chatMsg = JSON.parse(json.Message);
          if (Array.isArray(chatMsg)){
            for(let i = 0 ; i<chatMsg.length; i++)
              print_chat(chatMsg[i]);
          }
          else
            print_chat(chatMsg);
        }
        else
        {
          console.log(json.Message);
          if(!interactive_session){
            setTimeout(function() {
            exitcode=0;
            ws.close();
            ws.terminate();
            },25);
	        }
	      }
      }
    } else
    {
      if(!values.silent){
        console.log('RconApp::Error: Invalid JSON received')
      }
    } 
  } catch (e) {
    if(!values.silent){
      if (e) console.log('RconApp::Error:', e)
    }
  }
})

ws.on('close', function () {
  process.exit(exitcode)
});

ws.on('error', function (e) {
  if(!values.silent){
    console.log('RconApp::Error:', e)
    console.log('Perhaps rust is not up yet or the password is not set?')
  }
  process.exit(exitcode)
})

function createPacket (command, id = -1) {
  var packet =
  {
    Identifier: id == -1 ? ourselves : ourselves+id,
    Message: command,
    Name: 'WebRcon'
  }
  return JSON.stringify(packet)
}
