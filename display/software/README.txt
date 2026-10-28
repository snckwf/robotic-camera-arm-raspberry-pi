ROBOTIC ARM - 16x2 LCD DISPLAY OPTION
=====================================
Full article (in Italian): https://www.emgi.it/2026/10/19/braccio-robotico-telecamera-raspberry-pi-stampato-3d/

The easiest way to install everything is to let Claude guide you (claude.ai or Claude Desktop):
attach this zip, or the single files, and ask for the procedures one step at a time.
Claude reads the files, tells you what to type and checks the result with you.
Example: "I have connected the LCD display to the arm: help me install display_lcd.py and test it."

WHAT'S INSIDE
-------------
display_lcd.py        shows joint positions and light; HTTP server on port 8092 for messages
                      (GET /lcd?r1=Hello&r2=World&sec=10 - used by Claude and the controller)
display-lcd.service   automatic start

INSTALLATION
------------
1. I2C enabled (sudo raspi-config -> Interface Options -> I2C) and: sudo apt install -y python3-smbus2 i2c-tools
2. sudo cp display_lcd.py /opt/braccio/ ; sudo cp display-lcd.service /etc/systemd/system/
3. sudo systemctl daemon-reload ; sudo systemctl enable --now display-lcd
4. Test: i2cdetect -y 1 -> 40 (PCA9685) and 27 or 3f (display). Contrast: blue trimmer on the I2C module.
braccio_web.py must be running (arm package).
