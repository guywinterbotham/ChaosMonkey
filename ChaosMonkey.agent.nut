// Trigger the CHAOS Monkey to play its cymbols for a given number of seconds
// as supplied via a URL prarameter "chaos"
// Log the URLs we need
server.log("Excite the CHAOS Monkey for n seconds: " + http.agenturl() + "?chaos=n");
server.log("Change the color of the ChaosMonkey R,G,B: 0-9: " + http.agenturl() + "?color=RRRGGGBBB");

// Process a webhook tossed the Monkey's way.
function requestHandler(request, response) {
  try {
    // Check if the user sent "color" as a query parameter
    if ("color" in request.query) {
      device.send("color", request.query.color);
    }

    if ("blinkm" in request.query) {
      device.send("blinkm", request.query.blinkm);
    }

    // Check if the user sent "play" as a query parameter
    if ("voice" in request.query) {
      device.send("voice", request.query.voice);
    }

    // Check if the user sent "on" as a query I2C bit parameter
    if ("on" in request.query) {
      device.send("on", request.query.on);
    }

    // Check if the user sent "off" as a query I2C bit parameter
    if ("off" in request.query) {
      device.send("off", request.query.off);
    }

    // Check if the user sent "chaos" as a query parameter
    if ("chaos" in request.query) {

      // If they did, convert the time to an integer
      local chaosTime = request.query.chaos.tofloat();
  
      // Range check the time and pick an arbitary upper limit of 30 secs
      // and a lower range of 3 secs
      if (chaosTime < 3.0) {
        chaosTime = 3.0;
      }
  
      if (chaosTime > 30.0) {
        chaosTime = 30.0;
      }

      // Send "chaosTime" message to device, and send ledState as the data
      device.send("chaos", chaosTime);
    }

    // Respond back saying everything was OK...
    response.send(200, "OK");
  } catch (ex) {
  // or that it was not
    response.send(500, "Internal Server Error: " + ex);
  }
}
 
// register the HTTP handler
http.onrequest(requestHandler);
