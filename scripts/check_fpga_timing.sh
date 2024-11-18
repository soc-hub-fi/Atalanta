FAILED=$(cat fpga/build/RT-SS_fpga/vivado_RT-SS_fpga.log | grep -cF -e "ERROR")

if [ "$FAILED" -ge 1 ]
then
	echo "Found ERROR in FPGA run, exiting..."
	exit 1
fi
