Pi Zero 2 W – DIY Rubber Ducky Setup
====================================

This setup turns a Raspberry Pi Zero 2 W into a USB HID "Rubber Ducky"
that, when plugged into a Windows machine, automatically opens:

  https://www.youtube.com/@josiahgold3n?sub_confirmation=1


Files
-----

1) setup_pi_ducky.sh
   - Base setup script
   - Enables USB OTG HID keyboard mode
   - Creates the HID gadget config (hid-setup-gadget.sh + hidg.service)
   - Installs python3
   - Creates /usr/local/bin/hid-keypress
   - Creates duckypayload.service which calls /usr/local/bin/duckypayload.sh

2) duckypayload.sh
   - Windows-only payload
   - Waits for /dev/hidg0, gives Windows time to detect the keyboard,
     then uses the hid-keypress helper to:
       - Press Win + R
       - Clear the Run box
       - Type the YouTube URL with sub_confirmation=1
       - Press Enter


How to Use (Fresh Pi Zero 2 W)
------------------------------

0. Flash Raspberry Pi OS Lite (64-bit) onto the SD card.
   - Enable SSH (e.g., by adding an empty "ssh" file to the boot partition).
   - Boot the Pi Zero 2 W and SSH into it.

1. Copy the scripts to the Pi (or create them with nano):

   - Save the setup script "setup_pi_ducky.sh" to the Pi, e.g.:

       nano setup_pi_ducky.sh
       # paste script contents
       Ctrl+O, Enter, Ctrl+X

   - Make it executable:

       chmod +x setup_pi_ducky.sh

2. Run the base setup script as root:

       sudo ./setup_pi_ducky.sh

   This will:
   - Install python3
   - Configure OTG in /boot config.txt and cmdline.txt
   - Create /usr/local/bin/hid-setup-gadget.sh
   - Create and enable hidg.service
   - Create /usr/local/bin/hid-keypress
   - Create and enable duckypayload.service (but duckypayload.sh itself
     still needs to be created in the next step)

3. Create the Windows payload script:

   - Edit the file:

       sudo nano /usr/local/bin/duckypayload.sh

   - Paste the contents of the "duckypayload.sh" script.
   - Save and exit, then:

       sudo chmod +x /usr/local/bin/duckypayload.sh
       sudo systemctl daemon-reload
       sudo systemctl restart duckypayload.service

4. Reboot the Pi:

       sudo reboot

5. Using it as a Rubber Ducky:

   - Power the Pi (either from the target or from a separate power source).
   - When ready to "strike", plug the Pi’s USB DATA port into the Windows target.
   - After a few seconds:
       - The Pi appears as a USB keyboard.
       - It presses Win+R, types the YouTube URL, and hits Enter.
       - The browser opens your channel with the subscribe prompt.


Notes
-----

- This setup is primarily tuned for Windows. For other OSes (Linux/macOS),
  you can create alternate payload scripts (e.g., duckypayload_linux.sh)
  using the same hid-keypress helper and then point duckypayload.service
  to whichever payload you want to auto-run.

- To change what the ducky does, just edit /usr/local/bin/duckypayload.sh
  and update the sequence of keys and strings:

    - Use "<GUI+r>" for Win+R
    - Use "<CTRL+ALT+t>" for Linux terminals
    - Use "<CMD+SPACE>" for macOS Spotlight
    - Normal text is typed as-is
    - Special keys like <ENTER>, <BACKSPACE>, <TAB> are supported


Reset / Disable
---------------

- To disable the auto payload running on boot:

    sudo systemctl disable duckypayload.service

- To re-enable later:

    sudo systemctl enable duckypayload.service

- To stop the HID gadget (keyboard) from being configured on boot:

    sudo systemctl disable hidg.service

  (Re-enable with `sudo systemctl enable hidg.service`)
