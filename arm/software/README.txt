3D-PRINTED BENCH ROBOTIC ARM WITH CAMERA - ARM SOFTWARE
=======================================================
Full article (in Italian): https://www.emgi.it/2026/10/19/braccio-robotico-telecamera-raspberry-pi-stampato-3d/

The easiest way to install everything is to let Claude guide you (claude.ai or Claude Desktop):
attach this zip, or the single files, and ask for the procedures one step at a time.
Claude reads the files, tells you what to type and checks the result with you.
Examples:
  - "I have a Raspberry Pi 4 with Raspberry Pi OS: help me install CamUI and this software, one step at a time."
  - "Help me test the arm: one joint at a time, with simple questions."
  - "Explain how to create an SSH key on my PC and authorise it on the Raspberry."
  - "Connect the arm MCP server to my Claude Desktop."
  - "Set up the daily backup to my NAS."
  - "Install go2rtc and connect the arm camera to Home Assistant."

Note: file names, API paths, configuration keys and MCP tool names are kept in Italian as in the
running system (e.g. spalla = shoulder, gomito = elbow, rotazione = rotation, luce = light).

WHAT'S INSIDE
-------------
raspberry/opt/braccio/braccio_web.py   web server + motor control (port 8091)
raspberry/opt/braccio/ui/index.html    the web page: video, controls, zoom, photos, video, light, positions, calibration
raspberry/systemd/*.service            automatic start: braccio-web, camui, go2rtc
raspberry/go2rtc/go2rtc.yaml           go2rtc: H.264 video (hardware encoder), RTSP, recording
raspberry/braccio_mcp/mcp_braccio.py   MCP server for Claude (standard library only)
raspberry/braccio_mcp/mcp.json         joints locked for Claude, e.g. {"bloccati": ["spalla","gomito"]}
raspberry/maintenance/                 daily backup (local + NAS), watchdog, security updates
claude_desktop/                        Claude Desktop configuration (Windows): two ways, see below

Options with their own package: 16x2 LCD display (display_lcd.py) and joystick controller (controller_braccio.py).

WHAT TO REPLACE (UPPERCASE placeholders)
----------------------------------------
YOUR_USER               the Raspberry user (the one you log in with over SSH, e.g. pi)
PI_IP                   the Raspberry IP address (better fixed, set in the router)
YOUR_WINDOWS_USER       your Windows user (folder C:\Users\...)
YOUR_FOLDER             where you put avvio_braccio.py on the PC
NAS_IP, SHARE_NAME, NAS_FOLDER_NAME   backup copy on the NAS (if you have no NAS, ignore)
NAS_USER / NAS_PASSWORD only in the file /etc/braccio-nas.cred on the Pi (chmod 600, owner root).
Type the passwords yourself: do not put them in scripts and do not paste them in a chat.

WHERE EACH FILE GOES ON THE RASPBERRY
-------------------------------------
/opt/braccio/                        braccio_web.py, ui/index.html
/home/YOUR_USER/braccio_mcp/         mcp_braccio.py, mcp.json
/etc/systemd/system/                 the .service and .timer files
/etc/go2rtc/go2rtc.yaml              + the go2rtc program in /usr/local/bin/go2rtc (linux_arm64 from
                                       https://github.com/AlexxIT/go2rtc/releases)
/usr/local/bin/backup-braccio.sh     (chmod 755)
/etc/systemd/system.conf.d/watchdog.conf
/etc/apt/apt.conf.d/                 20auto-upgrades and 52braccio-unattended (from maintenance/updates/)
/etc/braccio-nas.cred                from maintenance/braccio-nas.cred.example, with your NAS data

PACKAGES (Raspberry Pi OS Bookworm or later)
--------------------------------------------
sudo apt install -y git python3-flask python3-picamera2 python3-pil python3-lgpio python3-spidev \
                    python3-smbus2 i2c-tools ffmpeg smbclient unattended-upgrades
CamUI:  git clone https://github.com/monkeymademe/CamUI.git ~/CamUI   (service: raspberry/systemd/camui.service)
Enable I2C and SPI (sudo raspi-config -> Interface Options). In /boot/firmware/config.txt, [all] section:
  dtparam=spi=on
  core_freq=500
  core_freq_min=500
(a fixed core_freq is needed by the LED ring on SPI.)

SERVOS AND PCA9685
------------------
The servos are driven by the PCA9685 board (I2C 0x40): CH0 shoulder, CH1 elbow, CH2 tilt, CH3 rotation.
Test: "i2cdetect -y 1" must show 40. Use 180-degree MG996R servos, NOT the continuous rotation ones (360).
Without the PCA9685 the servos can also be driven from the GPIOs: in /opt/braccio/dati/config.json, for each servo,
"tipo": "hw" (hardware PWM on GPIO12/13, needs dtoverlay=pwm-2chan,pin=12,func=4,pin2=13,func2=4 in config.txt)
or "tipo": "sw" with "gpio": number (software pulses, the servos jitter a little).

VIDEO
-----
Recommended video resolution 1640x1232 (arm page -> Image -> Video): at 3280x2464 the CamUI JPEG
encoding takes all 4 cores of the Pi 4. Photos stay at 8 MP with "High quality".
Recording (Record button, or the "registra" tool for Claude) saves MP4 files in /opt/braccio/dati/video
taking the video from go2rtc without re-encoding. Videos are not included in the backup.

CLAUDE DESKTOP (Windows)
------------------------
Two ways, choose one and put it in claude_desktop_config.json:
 1. claude_desktop_config_ssh.json: Claude Desktop starts ssh to the Pi. Simple, but if the Pi is off
    Claude Desktop reports an error at startup.
 2. claude_desktop_config_avvio.json + avvio_braccio.py (needs Python on the PC): answers at once with the list of
    tools and connects to the Pi only when Claude uses them. Pi off = no error, just a message.
The SSH key (id_ed25519_pi) is created on the PC and authorised on the Pi: ask Claude for the procedure.

TESTING
-------
Open http://PI_IP:8091 -> press "Home base" to zero the base with the Hall sensor, then the Calibration section:
for each servo set zero, direction and limits with small movements. The STOP button (or Esc) stops everything.

SECURITY
--------
Claude's SSH access with passwordless sudo gives full control of the Raspberry: use a dedicated key,
do not share it, and remove it when not needed (delete the file in /etc/sudoers.d/ and the line in
~/.ssh/authorized_keys). The MCP server respects the joints listed in mcp.json as "bloccati" (locked).
