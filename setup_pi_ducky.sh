#!/bin/bash
# setup_pi_ducky.sh
# Run as: sudo ./setup_pi_ducky.sh

set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root (sudo $0)" >&2
  exit 1
fi

echo "[*] Installing basic packages..."
apt-get update
apt-get install -y python3

echo "[*] Detecting boot config paths..."
if [ -f /boot/firmware/config.txt ]; then
  BOOTCFG="/boot/firmware/config.txt"
else
  BOOTCFG="/boot/config.txt"
fi

if [ -f /boot/firmware/cmdline.txt ]; then
  CMDLINE="/boot/firmware/cmdline.txt"
else
  CMDLINE="/boot/cmdline.txt"
fi

echo "[*] Using BOOT config: $BOOTCFG"
echo "[*] Using CMDLINE:    $CMDLINE"

echo "[*] Enabling dwc2 overlay (USB OTG)..."
if ! grep -q "dtoverlay=dwc2" "$BOOTCFG"; then
  echo "dtoverlay=dwc2" >> "$BOOTCFG"
fi

echo "[*] Ensuring modules-load=dwc2,libcomposite in cmdline..."
if ! grep -q "modules-load=dwc2,libcomposite" "$CMDLINE"; then
  LINE="$(cat "$CMDLINE")"
  echo "modules-load=dwc2,libcomposite $LINE" > "$CMDLINE"
fi

echo "[*] Creating HID gadget setup script..."
cat <<'EOF' >/usr/local/bin/hid-setup-gadget.sh
#!/bin/bash
set -e

GADGET_DIR="/sys/kernel/config/usb_gadget/pi_ducky"

modprobe libcomposite

if ! mountpoint -q /sys/kernel/config; then
  mount -t configfs none /sys/kernel/config
fi

if [ -d "$GADGET_DIR" ]; then
  echo "Gadget already exists, skipping."
  exit 0
fi

mkdir -p "$GADGET_DIR"

echo 0x1d6b > "$GADGET_DIR/idVendor"      # Linux Foundation (fine for lab use)
echo 0x0104 > "$GADGET_DIR/idProduct"     # Multifunction Composite Gadget
echo 0x0100 > "$GADGET_DIR/bcdDevice"
echo 0x0200 > "$GADGET_DIR/bcdUSB"

mkdir -p "$GADGET_DIR/strings/0x409"
echo "QUX-$(cat /proc/sys/kernel/random/uuid)" > "$GADGET_DIR/strings/0x409/serialnumber"
echo "QuixoteDucky" > "$GADGET_DIR/strings/0x409/manufacturer"
echo "Pi Zero Ducky" > "$GADGET_DIR/strings/0x409/product"

mkdir -p "$GADGET_DIR/configs/c.1/strings/0x409"
echo "Config 1: HID Keyboard" > "$GADGET_DIR/configs/c.1/strings/0x409/configuration"
echo 120 > "$GADGET_DIR/configs/c.1/MaxPower"

mkdir -p "$GADGET_DIR/functions/hid.usb0"
echo 1 > "$GADGET_DIR/functions/hid.usb0/protocol"        # keyboard
echo 1 > "$GADGET_DIR/functions/hid.usb0/subclass"
echo 8 > "$GADGET_DIR/functions/hid.usb0/report_length"

cat <<'DESC' > "$GADGET_DIR/functions/hid.usb0/report_desc"
\x05\x01\x09\x06\xa1\x01\x05\x07\x19\xe0\x29\xe7\x15\x00\x25\x01\x75\x01\x95\x08\x81\x02\x95\x01\x75\x08\x81\x01\x95\x05\x75\x01\x05\x08\x19\x01\x29\x05\x91\x02\x95\x01\x75\x03\x91\x01\x95\x06\x75\x08\x15\x00\x25\x65\x05\x07\x19\x00\x29\x65\x81\x00\xc0
DESC

ln -s "$GADGET_DIR/functions/hid.usb0" "$GADGET_DIR/configs/c.1/"

UDC="$(ls /sys/class/udc | head -n1)"
echo "$UDC" > "$GADGET_DIR/UDC"

echo "HID gadget configured and bound to $UDC"
EOF

chmod +x /usr/local/bin/hid-setup-gadget.sh

echo "[*] Creating hidg.service..."
cat <<'EOF' >/etc/systemd/system/hidg.service
[Unit]
Description=Configure USB HID gadget (keyboard) at boot
After=multi-user.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/local/bin/hid-setup-gadget.sh

[Install]
WantedBy=multi-user.target
EOF

echo "[*] Creating hid-keypress helper..."
cat <<'EOF' >/usr/local/bin/hid-keypress
#!/usr/bin/env python3
import sys

HID_DEVICE = "/dev/hidg0"

MOD = {
    "CTRL": 0x01,
    "SHIFT": 0x02,
    "ALT": 0x04,
    "GUI": 0x08,  # Windows key / Command on Mac
    "CMD": 0x08,  # alias for Mac use
}

KEY = {
    "ENTER": 40,
    "ESC": 41,
    "BACKSPACE": 42,
    "TAB": 43,
    "SPACE": 44,
    "F1": 58, "F2": 59, "F3": 60, "F4": 61, "F5": 62, "F6": 63,
    "F7": 64, "F8": 65, "F9": 66, "F10": 67, "F11": 68, "F12": 69,
}

CHARMAP = {
    # letters
    'a': (0, 4),  'b': (0, 5),  'c': (0, 6),  'd': (0, 7),
    'e': (0, 8),  'f': (0, 9),  'g': (0,10),  'h': (0,11),
    'i': (0,12),  'j': (0,13),  'k': (0,14),  'l': (0,15),
    'm': (0,16),  'n': (0,17),  'o': (0,18),  'p': (0,19),
    'q': (0,20),  'r': (0,21),  's': (0,22),  't': (0,23),
    'u': (0,24),  'v': (0,25),  'w': (0,26),  'x': (0,27),
    'y': (0,28),  'z': (0,29),

    # numbers
    '1': (0, 30), '2': (0, 31), '3': (0, 32), '4': (0, 33),
    '5': (0, 34), '6': (0, 35), '7': (0, 36), '8': (0, 37),
    '9': (0, 38), '0': (0, 39),

    # basic punctuation
    ' ': (0, 44),
    '.': (0, 55),
    ',': (0, 54),
    '/': (0, 56),
    '-': (0, 45),
    '=': (0, 46),

    # extras used in URLs
    ';': (0, 51),
    ':': (0x02, 51),       # Shift + ;
    '@': (0x02, 31),       # Shift + 2
    '_': (0x02, 45),       # Shift + -
    '?': (0x02, 56),       # Shift + /
}

def send_report(mod, keycode):
    report = bytes([mod, 0, keycode, 0, 0, 0, 0, 0])
    try:
        with open(HID_DEVICE, "rb+", buffering=0) as fd:
            fd.write(report)
            fd.write(b"\x00" * 8)
        return 0
    except FileNotFoundError:
        print(f"{HID_DEVICE} not found. Is the HID gadget loaded?")
        return 1
    except PermissionError:
        print(f"Permission denied writing to {HID_DEVICE}. Try sudo.")
        return 1
    except BrokenPipeError:
        print("Broken pipe writing to HID device (host not ready yet?)")
        return 1
    except OSError as e:
        print(f"OS error talking to {HID_DEVICE}: {e}")
        return 1

def type_text(text: str) -> int:
    rc = 0
    for ch in text:
        lower = ch.lower()
        if lower not in CHARMAP:
            continue
        mod, code = CHARMAP[lower]
        r = send_report(mod, code)
        if r != 0:
            rc = r
    return rc

def parse_and_send(token: str) -> int:
    if token.startswith("<") and token.endswith(">"):
        inside = token[1:-1].upper()

        if inside in KEY:
            return send_report(0, KEY[inside])

        parts = [p.strip() for p in inside.split("+")]
        mod = 0
        keycode = None

        for p in parts:
            if p in MOD:
                mod |= MOD[p]
            elif p.lower() in CHARMAP:
                _, keycode = CHARMAP[p.lower()]
            else:
                print(f"Unknown token part: {p}")

        if keycode is not None:
            return send_report(mod, keycode)
        return 1

    return type_text(token)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: hid-keypress <text or commands>")
        sys.exit(1)

    rc_total = 0
    for arg in sys.argv[1:]:
        rc = parse_and_send(arg)
        if rc != 0:
            rc_total = rc

    sys.exit(rc_total)
EOF

chmod +x /usr/local/bin/hid-keypress

echo "[*] Creating duckypayload.service (expects /usr/local/bin/duckypayload.sh)..."
cat <<'EOF' >/etc/systemd/system/duckypayload.service
[Unit]
Description=Run Pi Ducky Payload on Boot
After=multi-user.target hidg.service
Wants=hidg.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/duckypayload.sh

[Install]
WantedBy=multi-user.target
EOF

echo "[*] Enabling services..."
systemctl daemon-reload
systemctl enable hidg.service
systemctl enable duckypayload.service

echo
echo "[*] Base setup complete!"
echo "Now create /usr/local/bin/duckypayload.sh (Windows payload) using the separate script file,"
echo "then reboot the Pi."
