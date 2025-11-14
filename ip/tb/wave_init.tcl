# Load saved waveform config into the live simulation
open_wave_config viv_mod_wave.wcfg

# OPTIONAL: force-enable all signals
log_wave -r *

# Refresh the waveform window
update_wave
