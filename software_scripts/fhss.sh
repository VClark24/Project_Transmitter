#!/bin/sh

#Increase dwell time if glitching observed
DWELL_TIME=0.1

IIO_DEV="/sys/bus/iio/devices/iio:device1"
LO_ATTR="$IIO_DEV/out_altvoltage1_TX_LO_frequency"

CHANNELS="2400000000 2420000000 2440000000 2460000000 2480000000" #5 frequency channels available

if [ ! -e "$LO_ATTR" ]; then                                      #Safety check
    echo "Error: TX LO frequency attribute not found: $LO_ATTR"   
    exit 1
fi

echo "FHSS started"

while true
do
    FREQ=$(echo $CHANNELS | tr ' ' '\n' | shuf | head -n 1) #shuf randomises the order

    echo $FREQ > $IIO_DEV/out_altvoltage1_TX_LO_frequency

    echo "$FREQ" > "$LO_ATTR"          

    echo "TX -> $FREQ Hz"

    sleep $DWELL_TIME
done
