FAILED=$(cat fpga/build/RT-SS_fpga/vivado_RT-SS_fpga.log | grep -cF -e "failed to meet the timing")

if [ "$FAILED" -ge 1 ]
then
	echo "ERROR: TIMING FAILED"
	exit 1
fi
