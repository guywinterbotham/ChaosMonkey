// TODO: Write lipSync routine and test whether class function can be used as a callback
// Pin Assignments
// 1 PWM Servo
// 2 Clk Sound Card			
// 5 Data Sound Card
// 7 Busy		
// 8 I2C
// 9 I2C
// 
// Extender
// 1 Reset
// 2 Clapper

// Global constants which for some reason can't be declared inside the class
// Special Commands for the Audio-Sound Breakout - WTV020SD
const PLAY_PAUSE = 0xFFFE
const STOP = 0xFFFF
const VOLUME_MIN = 0xFFF0
const VOLUME_MAX = 0xFFF7
  
// Servo Linits: These values may be different for your servo
// To dertermine, start with 0 and say 1 and experiment with the values
// that cause the servo to move. Peg to highest and lowest respectively
// Print out the values as you go
const SERVO_MIN = 0.04
const SERVO_MAX = 0.1 // Large servo
//const SERVO_MAX = 0.11375 //small servo
const MAX_POSITION = 60 // In percent of range
const MIN_POSITION = 10 // Should be < Max


const SLEEP_TIME = 1    // in minutes
const SERVO_SWEEP = 0.2 // in seconds
//const SERVO_SWEEP = 1 // in seconds TEST
const WAKEUP_VOICE = 12 // Voice to play when imp powers on

// Base class for MCP23008 and MCP23017 family of I2C i/o expanders
class MCP230xx {
  BASE_ADDR = 0x20
  i2cPort = null
  i2cAddr = null
  regs = null

  constructor(i2cPort, deviceAddr) {
    this.i2cPort = i2cPort
    this.i2cAddr = (BASE_ADDR + deviceAddr) << 1
  }

  // Read a byte
  function read(reg) {
    local data = i2cPort.read(i2cAddr, format("%c", reg), 1)
    if(data == null) {
      server.log("I2C Read Failure")
      return -1
    }
    return data[0]
  }

  // Write a byte
  function write(reg, data) {
    i2cPort.write(i2cAddr, format("%c%c", reg, data))
  }

  // Set/clear a bit in a register
  function writeBit(reg, bitn, level) {
    local value = read(reg)
    value = (level == 0) ? (value & ~(1 << bitn)) : (value | (1 << bitn))
    write(reg, value)
  }

  function setValueForRegister(gpio, reg, value) {
    writeBit(regs[reg], gpio & 7, value)
  }

  function getValueForRegister(gpio, reg) {
    return (read(regs[reg]) & (1 << (gpio & 7))) ? 1 : 0
  }

  function setDir(gpio, input) {
    setValueForRegister(gpio, "IODIR", input ? 1 : 0)
  }

  function setPullUp(gpio, pull_up) {
    setValueForRegister(gpio, "GPPU", pull_up ? 1 : 0)
  }

  function setPin(gpio, level) {
    setValueForRegister(gpio, "GPIO", level ? 1 : 0)
  }

  function getPin(gpio) {
    return getValueForRegister(gpio, "GPIO")
  }
}

// This class is compatible with the general Pin class
class MCP230xxPin {
  device = null
  gpio = null
  regs = null

  constructor(device, gpio, regs) {
    this.device = device
    this.gpio = gpio
    this.regs = regs
  }

  function configure(mode) {
    device.regs = regs
    switch(mode) {
    case DIGITAL_IN:
      device.setDir(gpio, 1)
      device.setPullUp(gpio, 0)
      break
    case DIGITAL_IN_PULLUP:
      device.setDir(gpio, 1)
      device.setPullUp(gpio, 1)
      break
    case DIGITAL_OUT:
      device.setDir(gpio, 0)
      device.setPullUp(gpio, 0)
      break
    default:
      server.log("MCP230xxPin: Invalid mode")
    }
  }

  function read() {
    device.regs = regs
    return device.getPin(gpio)
  }

  function write(level) {
    device.regs = regs
    device.setPin(gpio, level)
  }
}

// Encapsulates a MCP23008 I2C i/o expander
class MCP23008 extends MCP230xx {
  REGS = {
    IODIR = 0x00
    IOPOL = 0x01
    GPINTEN = 0x02
    DEFVAL = 0x03
    INTCON = 0x04
    IOCON = 0x05
    GPPU = 0x06
    INTF = 0x07
    INTCAP = 0x08
    GPIO = 0x09
    OLAT = 0x0A
  }
  pin1 = null
  pin2 = null
  pin3 = null
  pin4 = null
  pin5 = null
  pin6 = null
  pin7 = null
  pin8 = null

  constructor(i2cPort, deviceAddr) {
    base.constructor(i2cPort, deviceAddr)
    for(local gpio = 1; gpio <= 8; gpio++) {
      this["pin" + gpio] = MCP230xxPin(this, gpio - 1, REGS)
      this["pin" + gpio].configure(DIGITAL_OUT);
    }
  }
}


// Class for the sound board. 
class Voice {

  _clockPin = null
  _dataPin = null
  _resetPin = null

  constructor(clockPin, dataPin, resetPin) {
    _clockPin = clockPin
    _clockPin.configure(DIGITAL_OUT)
    _clockPin.write(1); // Initialize clock high to avoid reading false data
    _dataPin = dataPin
    _dataPin.configure(DIGITAL_OUT)
    _resetPin = resetPin
    _resetPin.configure(DIGITAL_OUT)
    _resetPin.write(0); // Initialize reset low
  }
  
  // SOUNDCARD Related Controls 
  function reset() {
    server.log("Reset Sound")
    _resetPin.write(1)
    imp.sleep(0.100) // Pulse the Reset Pin for 100 ms 
    _resetPin.write(0)
  }
  
  function playVoice(voiceNumber) {
    sendCommand(voiceNumber)
  }
  
  function asyncPlayVoice(voiceNumber){
    server.log("Async Playing Voice (Not Implmented)" + voiceNumber)
  }
  
  function stopVoice(){
    sendCommand(STOP)
    server.log("Stopped Voice")
  }
  
  function pauseVoice(){
    sendCommand(PLAY_PAUSE)
    server.log("Paused Voice")
  }
  
  function mute(){
    sendCommand(VOLUME_MIN)
    server.log("Muted Voice")
  }
  
  function unmute(){
    sendCommand(VOLUME_MAX)
    server.log("Unmuted Voice")
  }
  
  // The guts of the interface is the timing related to sending
  // the voice or special case command
  function sendCommand(command){
    local iCommand = command.tointeger()
    //Start bit Low level pulse.
    _clockPin.write(0);
    imp.sleep(0.020);  // 20 milli seconds
    
    for (local mask = 0x8000; mask > 0; mask = mask >> 1) {
      //Clock low level pulse.
      _clockPin.write(0)
      imp.sleep(0.000050) // 50 micro seconds
      //Write data setup.
      if (iCommand & mask) {
        _dataPin.write(1)
      }
      else {
        _dataPin.write(0)
      }
      
      //Write data hold.
      imp.sleep(0.000050) // 50 micro seconds
    
      //Clock high level pulse.
      _clockPin.write(1)
      imp.sleep(0.000100) // 100 micro seconds

      if (mask>0x0001){
        //Stop bit high level pulse.
        imp.sleep(0.002) // 2 milli seconds
      }
    }
    //Busy active high from last data bit latch.
    imp.sleep(0.020) // 20 milli seconds

  }
  
}

// Class for the servo motor
// Assumptions for powersaving: Deep sleep is used this will tristate the servo controller
// When the imp awakens it reconstructs everything
// Lipsync function can be used as the taken as a parameter a wakeup call
class Jaws {
  _mouthPin = null  // Controls the Server
  _earPin = null    // Listens for when sounds is being generated
  _position = MIN_POSITION
  _returning = 0    // Used to tristate the servo to save power
    
  constructor(mouthPin, earPin) {
    _mouthPin = mouthPin
    _mouthPin.configure(DIGITAL_IN) // Tri state servo
    _earPin = earPin
    _earPin.configure(DIGITAL_IN, this.lipSync.bindenv(this))
  }
  
  //SERVO Related Commands

  // Servo position function that expects a value between 0 and 100
  function SetServoPercent(value) {
    local scaledValue = ((value.tofloat() / 100.0) * (SERVO_MAX-SERVO_MIN)) + SERVO_MIN
    _mouthPin.write(scaledValue)
  }  

  // Sweep the servo back and forward until the fat monkey stops singing
  function lipSync() {
    local busyState = _earPin.read()
    
    // If first time call trigger then wake up servo
    if (_returning == 0 && busyState == 1) { // If first time call, rising edge of trigger only
      server.log("Servo Enabled")
      _returning = 1
      _mouthPin.configure(PWM_OUT, 0.02, SERVO_MIN)
      //_mouthPin.configure(DIGITAL_OUT) // TEST: enable output
    }
    
    // If "hearing" a voice then move mouth
    if (_returning == 1 && busyState == 1) { 
      // Invert the position
      _position = _position == MAX_POSITION ? MIN_POSITION : MAX_POSITION
      SetServoPercent(_position)
      //server.log("Servo Swept")
      //_mouthPin.write(1)                // Test: write output
      // Wait:
      imp.wakeup(SERVO_SWEEP, this.lipSync.bindenv(this))
    }
    
    if (_returning == 1 && busyState == 0) {  // If last time call, trailing edge of trigger only
      server.log("Servo Disbled")
      _mouthPin.configure(DIGITAL_IN) // Tri state servo
      _returning = 0 // Forget we came back
    }
  }
  
}

// Class for BlinkM I2C RGB Device control
class BlinkM {
 
  _i2c = null
  _blinkMaddr = null

  constructor(i2c, address) {
    _i2c = i2c
    _blinkMaddr = address<<1    // Address shift is not documented but discovered in the forums. It may not be needed in the future
  }

  // For each color in the RRRGGGBBB string, slice out the intensity
  // and limit to the max of 255
  function set(colorString) {
    local red = (colorString.slice(0,3)).tointeger()

    red = red > 255 ? 255 : red

    local green = (colorString.slice(3,6)).tointeger()
    green = green > 255 ? 255 : green

    local blue = (colorString.slice(6)).tointeger()
    blue = blue > 255 ? 255 : blue
    
    server.log("Red: " + red + " Green: " + green + " Blue: " + blue);

    //blinkm: stop script
    local e = _i2c.write(_blinkMaddr, "o")

    // "f" -> Set Fade Speed, 1 -> slow, 255 -> instantly
    e = _i2c.write(_blinkMaddr, format("f%c", 10))

    // data c%c%c%c -> "c" + r + g + b
    // "c" -> Fade to RGB Color
    // "n" -> Go to RGB Color Now
    e = _i2c.write(_blinkMaddr, format("c%c%c%c", red, green, blue));
  }

  // Play a predefined script which is formatted as a string
  function script(playString) {
    server.log("BlinkM Script: " + playString)
    local param
    local e

    // "p" play script
    e = _i2c.write(_blinkMaddr, "p")

    local strLen = playString.len()
    for(local cmd = 0; cmd < strLen; cmd+=2) {
      param = playString.slice(cmd,cmd+2)
      e = _i2c.write(_blinkMaddr, format("%c", param.tointeger()))
      server.log("Param "+ param + " index: " + cmd + "respose: " + e)
    }
  }
}

// ** Setup including setting up the sleep times **

// Configure i2c bus that will control the BlinkM RGB LED
hardware.i2c89.configure(CLOCK_SPEED_100_KHZ)

// Create BlinkM object using I2C communications and the BlinkM bus address
blinkM <- BlinkM(hardware.i2c89, 0x09)

// Create i/o port instances (note: each device on the same bus should have a different device address)
IOExtender <- MCP23008(hardware.i2c89, 0) // pinstrapped to device address 0

// Create the output address for the cymbols motor
cymbals <- IOExtender.pin4
cymbals.configure(DIGITAL_OUT)

// Create the addresses used by the sound board
clockPin <- hardware.pin5
dataPin <- hardware.pin7
resetPin <- IOExtender.pin5
monkeyVoice <- Voice(clockPin,dataPin,resetPin)

// Create the addresses used by the servo
// ******************* Test there is voltage on ear Pin ***** then try slot again
mouthPin <- hardware.pin1
earPin <- hardware.pin2
monkeyMouth <- Jaws(mouthPin, earPin)

// ** Agent Handlers **
// Function to turn on the ChaosMonkey for a period of seconds
function BangCymbols(chaosTime) {
  server.log("Create chaos for: " + chaosTime + " seconds")
  cymbals.write(1)
  imp.wakeup(chaosTime, SilenceCymbols)
}

// Chained function for Cymbols 
function SilenceCymbols() {
  cymbals.write(0)
}

// Function to play a voice on the sound board
function Voice(voiceNumber) {
  monkeyVoice.playVoice(voiceNumber);
}

// Function to set the color of the ChaosMonkey's rear end
function SetColor(colorString) {
  blinkM.set(colorString)
}

// Function to set the color of the ChaosMonkey's rear end
function BlinkMScript(playString) {
  blinkM.script(playString)
}

// Servo position function that expects a value between 0 and 100
function SetServoPercent(value) {
  monkeyMouth.SetServoPercent(value)
}

// IOExtender pin function that expects a value between 0 and 7
function OnPin(value) {
  IOExtender["pin" + value].write(1)
  server.log("Turning ON pin " + value)
}
// Servo position function that expects a value between 0 and 7
function OffPin(value) {
  IOExtender["pin" + value].write(0)
  server.log("Turning OFF pin " + value)
}

// Register a handler for messages from the agent.
agent.on("color", SetColor)
agent.on("chaos", BangCymbols)
agent.on("voice",Voice)
agent.on("on",OnPin)
agent.on("off",OffPin)
agent.on("blinkm",BlinkMScript)

// Respond to the reason for waking up
function logDeviceOnline() {
    local reasonString = "code crash?";
    switch(hardware.wakereason()) 
    {
        case WAKEREASON_POWER_ON: 
            reasonString = "The power was turned on";
            blinkM.set("000000000")
            monkeyVoice.playVoice(WAKEUP_VOICE);
            break;
            
        case WAKEREASON_SW_RESET:
            reasonString = "A software reset took place";
            break;
            
        case WAKEREASON_TIMER:
            reasonString = "An event timer fired";
            break;
            
        case WAKEREASON_PIN1:
            reasonString = "Pulse detected on Wakeup Pin";
            break;
            
        case WAKEREASON_NEW_SQUIRREL:
            reasonString = "New Squirrel code downloaded";
            monkeyVoice.playVoice(WAKEUP_VOICE);
    }
    
    server.log("Monkey was poked because of " + reasonString);
} 

logDeviceOnline();


// ** Power saver functions
//imp.onidle(function() {
//  server.log("Idle for " + SLEEP_TIME)
//  server.sleepfor(SLEEP_TIME * 60)
//});
