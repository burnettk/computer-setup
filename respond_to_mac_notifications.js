#!/usr/bin/env osascript -l JavaScript

// repl (via https://www.galvanist.com/posts/2020-03-28-jxa_notes/#access-the-repl):
// osascript -il JavaScript
// notificationCenter.windows()[0].buttons.whose({name: "Close"}).length
//
// to let this work, allow iTerm in:
//   Security & Privacy => Privacy => Accessibility
//   Security & Privacy => Privacy => Automation

console.log("started respond_to_mac_notifications.js")

function closeWindow(window, app){
  // app.displayAlert(`This is a message: ${window.buttons[1].name}`);

  window.buttons().forEach(function(button) {
    console.log(`button name: ${button.name().toString()}`)
  })

  // https://ryanmo.co/2016/04/18/clearing-multiple-notifications-in-mac-os-x/
  var buttonsWeWantToClick = window.buttons.whose({
    _or: [
      {name: "Show"},
      {name: "Allow"},
      {name: "Close"},
      {name: "OK"}
    ]
    })()
  console.log(`Found clickable button count on this window: ${buttonsWeWantToClick.length}`)
  buttonsWeWantToClick.forEach(function(button){ button.click() })
  delay(0.1); // The UI can't always keep up, so we introduce a short delay
}

var app = Application('System Events');
app.includeStandardAdditions = true;


var notificationCenter = app.processes.byName('NotificationCenter')

// test with just one window
var firstWindow = notificationCenter.windows()[0]
closeWindow(firstWindow, app)

// notificationCenter.windows().forEach(function(window) {
//   closeWindow(window, app)
// })
