#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

# Print the IP address
_IP=$(hostname -I) || true
if [ "$_IP" ]; then
  printf "My IP address is %s\n" "$_IP"
fi

# Start SDR initialisation
/usr/local/bin/init_sdr.sh

exit 0
root@analog:~# cat /user/local/bin/init_sdr.sh
cat: /user/local/bin/init_sdr.sh: No such file or directory
root@analog:~# cat /usr/local/bin/init_sdr.sh
#!/bin/bash

echo "[SDR INIT] Starting..."

sleep 2

# Set sampling rate
iio_attr -c ad9361-phy voltage0 sampling_frequency 25000000 > /dev/null
iio_attr -c ad9361-phy voltage1 sampling_frequency 25000000 > /dev/null

# Set Output Frequency
iio_attr -u local: -c ad9361-phy altvoltage1 frequency 2400000000

# Set DMA Output
iio_reg cf-ad9361-dds-core-lpc 0x418 0x2
iio_reg cf-ad9361-dds-core-lpc 0x458 0x2

# Disable DDS tones
iio_attr -c cf-ad9361-dds-core-lpc TX1_I_F1 scale 0 > /dev/null
iio_attr -c cf-ad9361-dds-core-lpc TX1_Q_F1 scale 0 > /dev/null
iio_attr -c cf-ad9361-dds-core-lpc TX1_I_F2 scale 0 > /dev/null
iio_attr -c cf-ad9361-dds-core-lpc TX1_Q_F2 scale 0 > /dev/null
iio_attr -c cf-ad9361-dds-core-lpc TX2_I_F1 scale 0 > /dev/null
iio_attr -c cf-ad9361-dds-core-lpc TX2_Q_F1 scale 0 > /dev/null
iio_attr -c cf-ad9361-dds-core-lpc TX2_I_F2 scale 0 > /dev/null
iio_attr -c cf-ad9361-dds-core-lpc TX2_Q_F2 scale 0 > /dev/null

echo "[SDR INIT] Sampling rate set to 25 MSPS"
echo "[SDR INIT] Done"
exit 0
