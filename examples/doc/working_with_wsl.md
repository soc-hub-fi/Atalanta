# Working with WSL

## Forwarding a USB device to WSL

N.b., this process requires local admin rights so you won't be able to do it on a TUNI maintained system.

Install [usbipd-win](https://github.com/dorssel/usbipd-win).

```ps
usbipd --help
usbipd list
# Expose device to WSL (survives reboots)
usbipd bind --wsl --busid=<BUSID>
```
