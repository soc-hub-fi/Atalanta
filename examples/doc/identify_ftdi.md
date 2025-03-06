# Identify FTDI

```sh
# Prints the "adapter serial" for a connected FTDI chip
lsusb -v -d 0403:6010 2>/dev/null | grep iSerial | awk '{ print $3 }'

# List all connectd USB devices
lsusb
```
