ROBOTIC ARM - REMOTE CONTROLLER OPTION (Arduino Nano + 2 joysticks + 4 buttons)
================================================================================
Controller article (in Italian): https://www.emgi.it/2026/10/23/controller-joystick-braccio-robotico-arduino-nano/
Arm article (in Italian): https://www.emgi.it/2026/10/19/braccio-robotico-telecamera-raspberry-pi-stampato-3d/

The easiest way to install everything is to let Claude guide you (claude.ai or Claude Desktop):
attach this zip, or the single files, and ask for the procedures one step at a time.
Claude reads the files, tells you what to type and checks the result with you.
Example: "I have built the arm controller: help me upload the sketch to the Nano and install controller_braccio.py."

WHAT'S INSIDE
-------------
arduino/arm_console/arm_console.ino     Nano sketch: sends "J,a0,a1,a2,a3,buttons" at 115200 baud
raspberry/controller_braccio.py         reads the Nano over USB and moves the arm (braccio_web.py API)
raspberry/controller-braccio.service    automatic start

INSTALLATION
------------
1. Upload the sketch to the Nano with the Arduino IDE (board "Arduino Nano"; CH340 clones sometimes need
   "ATmega328P (Old Bootloader)").
2. On the Pi: sudo apt install -y python3-serial
3. sudo cp raspberry/controller_braccio.py /opt/braccio/ ; sudo cp raspberry/controller-braccio.service /etc/systemd/system/
4. sudo systemctl daemon-reload ; sudo systemctl enable --now controller-braccio
5. Connect the Nano to a USB port of the Pi. Log: journalctl -u controller-braccio -f

CONTROLS
--------
Left joystick: X = base, Y = shoulder. Right joystick: Y = elbow.
Buttons: tilt up / down, rotate left / right.
Left joystick button: short = STOP, held 2 s = HOME base. Right joystick button: light.
If a joint moves the wrong way: change its sign in SEGNO at the top of controller_braccio.py.
If the LCD display is also fitted, it shows STOP, HOME and light.
