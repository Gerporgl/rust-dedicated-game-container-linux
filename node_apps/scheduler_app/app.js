#!/usr/bin/env node

var debug = false

var childProcess = require('child_process')

var startupDelayInSeconds = 60 * 5
var runIntervalInSeconds = 60 * 5

if (debug) {
  startupDelayInSeconds = 1
  runIntervalInSeconds = 60
}

// Start the endless loop after a delay (allow the server to start)
setTimeout(function () {
  checkForUpdates()
}, 1000 * startupDelayInSeconds)

function checkForUpdates () {
  setTimeout(function () {
    if (debug) console.log('SchedulerApp::Running bash /app/update_check.sh')
    run_script("bash", ["/app/update_check.sh"], function(output, exit_code) {
      checkForUpdates()
    })
  }, 1000 * runIntervalInSeconds)
}

console.log ("Continuing to do node things while the process runs at the same time...");

// This function will output the lines from the script 
// AS is runs, AND will return the full combined output
// as well as exit code when it's done (using the callback).
function run_script(command, args, callback) {
    //console.log("Starting Process.");
    var child = childProcess.spawn(command, args);

    var scriptOutput = "";

    child.stdout.setEncoding('utf8');
    child.stdout.on('data', function(data) {
        console.log(data);

        data=data.toString();
        scriptOutput+=data;
    });

    child.stderr.setEncoding('utf8');
    child.stderr.on('data', function(data) {
        console.log(data);

        data=data.toString();
        scriptOutput+=data;
    });

    child.on('close', function(code) {
        callback(scriptOutput,code);
    });
}
