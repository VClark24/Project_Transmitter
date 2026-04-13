# ~/.bashrc: executed by bash(1) for non-login shells.

# Note: PS1 and umask are already set in /etc/profile. You should not
# need this unless you want different defaults for root.
# PS1='${debian_chroot:+($debian_chroot)}\h:\w\$ '
# umask 022

# You may uncomment the following lines if you want 'ls' to be colorized:
# export LS_OPTIONS='--color=auto'
# eval "$(dircolors)"
# alias ls='ls $LS_OPTIONS'
# alias ll='ls $LS_OPTIONS -l'
# alias la='ls $LS_OPTIONS -lA'

# Some more alias to avoid making mistakes:
# alias rm='rm -i'
# alias cp='cp -i'
# alias mv='mv -i'


start() {
    echo "Initialising Transmitter..."

    #Mute Initially
    busybox devmem 0x40004004 32 0x1

    #Select Beacon Waveform
    busybox devmem 0x40004000 32 0x2

    #Run PRBS23
    busybox devmem 0x40001000 32 0x1

    #Run Symbol Timer
    busybox devmem 0x40003000 32 0x1

    #Run Modulation Mapper
    busybox devmem 0x40000000 32 0x1

    #Run SRRC Filter
    busybox devmem 0x40002000 32 0x1

    #Unmute
    busybox devmem 0x40004004 32 0x0

    echo "Transmitter running in beacon mode"
}


stop() {
    echo "Stopping Transmitter..."

    #Function to stop FHSS is running
    stop_fhss() {
        if [ -f /tmp/fhss.pid ]; then
            kill $(cat /tmp/fhss.pid) 2>/dev/null
            rm -f /tmp/fhss.pid
            echo "FHSS stopped"
        fi
    }

    #Mute
    busybox devmem 0x40004004 32 0x1

    #Stop PRBS23
    busybox devmem 0x40001000 32 0x0

    #Stop Symbol Timer
    busybox devmem 0x40003000 32 0x0

    #Stop Modulation Mapper
    busybox devmem 0x40000000 32 0x0

    #Stop Filter
    busybox devmem 0x40002000 32 0x0

    echo "Transmitter operation Stopped"
}


restart() {
    echo "Restarting ..."

    #Function to stop FHSS is running
    stop_fhss() {
        if [ -f /tmp/fhss.pid ]; then
            kill $(cat /tmp/fhss.pid) 2>/dev/null
            rm -f /tmp/fhss.pid
            echo "FHSS stopped"
        fi

        iio_attr -u ip:analog.local -c ad9361-phy altvoltage1 frequency
    }

    #Mute
    busybox devmem 0x40004004 32 0x1;

    #Turn Off PRBS, Modulation Mapper, Symbol Timing and Filtering
    busybox devmem 0x40001000 32 0x0;
    busybox devmem 0x40000000 32 0x0;
    busybox devmem 0x40002000 32 0x0;
    busybox devmem 0x40003000 32 0x0;

    #Turn On PRBS, Modulation Mapper, Symbol Timing and Filtering
    busybox devmem 0x40003000 32 0x1;
    busybox devmem 0x40001000 32 0x1;
    busybox devmem 0x40002000 32 0x1;
    busybox devmem 0x40000000 32 0x1;

    #Set to Beacon Mode
    busybox devmem 0x40004000 32 0x2;

    #Unmute
    busybox devmem 0x40004004 32 0x0;

    echo "Transmitter operation resumed in beacon mode"
}


select_waveform() {

    #Function to stop FHSS is running
    stop_fhss() {
        if [ -f /tmp/fhss.pid ]; then
            kill $(cat /tmp/fhss.pid) 2>/dev/null
            rm -f /tmp/fhss.pid
            echo "FHSS stopped"
        fi

        iio_attr -u ip:analog.local -c ad9361-phy altvoltage1 frequency 2400000000
    }

    case "$1" in
        telecommand)
            stop_fhss
            busybox devmem 0x40004000 32 0x0
        ;;
        telemetry)
            stop_fhss
            busybox devmem 0x40004000 32 0x1
        ;;
        beacon)
            stop_fhss
            busybox devmem 0x40004000 32 0x2
        ;;
        fhss)
            busybox devmem 0x40004000 32 0x3

            #Start FHSS only if not already running
            if [ ! -f /tmp/fhss.pid ]; then
                ./fhss.sh > /tmp/fhss.log 2>&1 &
                echo $! > /tmp/fhss.pid
                echo "FHSS started"
            else
                echo "FHSS already running"
            fi
        ;;
        *)
            echo "Invalid Waveform";
            return 1
        ;;
    esac

    echo "Waveform changed to $1"
}


select_power() {
    case "$1" in
        low)
            echo "Transmit Power: LOW"
            iio_attr -u local: -o -c ad9361-phy voltage0 hardwaregain -20
            iio_attr -u local: -o -c ad9361-phy voltage1 hardwaregain -20
        ;;
        medium)
            echo "Transmit Power: MEDIUM"
            iio_attr -u local: -o -c ad9361-phy voltage0 hardwaregain -10
            iio_attr -u local: -o -c ad9361-phy voltage1 hardwaregain -10
        ;;
        high)
            echo "Transmit Power: HIGH"
            iio_attr -u local: -o -c ad9361-phy voltage0 hardwaregain 0
            iio_attr -u local: -o -c ad9361-phy voltage1 hardwaregain 0
        ;;
        *)
            echo "Usage: select_power {low | medium | high}"
        ;;
    esac
}


status() {
    wf_raw=$(busybox devmem 0x40004000 32 2>/dev/null)

    case "$wf_raw" in
        0x00000000|0)
            waveform="Telecommand"
            coding="BCH"
            modulation="BPSK"
            filtering="SRRC, alpha = 0.35"
            sample_rate="25 MSPS"
            data_rate="6.25 Mbps"
            symbol_rate="6.25 Msps"
            output_frequency="2.4 GHz"
        ;;
        0x00000001|1)
            waveform="Telemetry"
            coding="Convolutional"
            modulation="BPSK"
            filtering="SRRC, alpha = 0.35"
            sample_rate="25 MSPS"
            data_rate="6.25 Mbps"
            symbol_rate="6.25 Msps"
            output_frequency="2.4 GHz"
        ;;
        0x00000002|2)
            waveform="Beacon"
            coding="None"
            modulation="BPSK"
            filtering="SRRC, alpha = 0.35"
            sample_rate="25 MSPS"
            data_rate="6.25 Mbps"
            symbol_rate="6.25 Msps"
            output_frequency="2.4 GHz"
        ;;
        0x00000003|3)
            waveform="FHSS"
            coding="None"
            modulation="OQPSK"
            filtering="SRRC, alpha = 0.35"
            sample_rate="25 MSPS"
            data_rate="12.5 Mbps"
            symbol_rate="6.25 Msps"
            output_frequency="2.4 GHz to 2.48 GHz"
        ;;
        *)
            waveform="Unknown"
            coding="Unknown"
            modulation="Unknown"
            filtering="Unknown"
            sample_rate="Unknown"
            data_rate="Unknown"
            symbol_rate="Unknown"
        ;;
    esac

    echo "----------------------------------------"
    echo "SDR Transmitter Status"
    echo "----------------------------------------"
    echo "Selected waveform name : $waveform"
    echo "Output frequency       : $output_frequency"
    echo "Coding scheme          : $coding"
    echo "Modulation type        : $modulation"
    echo "Filtering type         : $filtering"
    echo "Sample rate            : $sample_rate"
    echo "Symbol rate            : $symbol_rate"
    echo "Data rate              : $data_rate"
    echo "----------------------------------------"
}


mute_on() {
    busybox devmem 0x40004004 32 0x1
    echo "Transmitter MUTED"
    echo "Use mute_off command to unmute"
}


mute_off() {
    busybox devmem 0x40004004 32 0x0
    echo "Transmitter UNMUTED"
}
