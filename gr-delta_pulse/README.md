# GNU Radio Delta Pulse Module

This GNU Radio Out-of-Tree (OOT) module provides blocks for delta pulse generation, suitable for channel sounding with SDRs.

## Features

- **Delta Pulse Source Block**: Generates delta-like pulses using an OFDM-style IFFT approach, suitable for channel estimation with SDRs like the Pluto SDR.

## Installation

### Prerequisites

- GNU Radio 3.8 or later
- CMake 3.8 or later
- Python 3.x
- NumPy

### Build and Install

1. Navigate to the module directory:
```bash
cd gr-delta_pulse
```

2. Create a build directory:
```bash
mkdir build
cd build
```

3. Configure and build:
```bash
cmake ..
make
```

4. Install (may require sudo):
```bash
sudo make install
sudo ldconfig
```

5. Verify installation:
```bash
gnuradio-config-info --prefix
```

The module should now be available in GNU Radio Companion (GRC) under the category `[delta_pulse]`.

## Usage

### In GNU Radio Companion (GRC)

1. Open GNU Radio Companion
2. The block will appear in the block tree under `[delta_pulse]` → `Delta Pulse Source`
3. Drag the block into your flowgraph
4. Configure the parameters:
   - **Pulse Length**: Number of samples in the pulse (default: 1024)
   - **Amplitude**: Output amplitude (keep ≤ 1.0 for SDRs, default: 0.8)
   - **Apply Hann Window**: Apply windowing to reduce ringing (default: True)
   - **Center Pulse**: Center the pulse in the array (default: True)
   - **Repeat Pulses**: Continuously repeat pulses (default: True)
   - **Number of Pulses**: Number of pulses to generate (-1 for infinite, default: -1)

### In Python

```python
from gnuradio import gr
from delta_pulse import delta_pulse_source

# Create a delta pulse source block
pulse_source = delta_pulse_source(
    pulse_length=1024,
    amplitude=0.8,
    window=True,
    center=True,
    repeat=True,
    num_pulses=-1
)
```

## Block Description

### Delta Pulse Source

The Delta Pulse Source block generates a delta-like pulse suitable for channel sounding. The pulse is created by:

1. Creating a frequency-domain signal with all ones
2. Performing an IFFT to get a time-domain impulse
3. Optionally centering the pulse
4. Optionally applying a Hann window to reduce spectral leakage
5. Normalizing to the specified amplitude

**Output**: Complex-valued samples (complex64)

**Parameters**:
- `pulse_length`: Number of samples in each pulse
- `amplitude`: Peak amplitude of the pulse (recommended ≤ 1.0 for SDRs)
- `window`: Apply Hann windowing to reduce ringing
- `center`: Center the pulse in the time array
- `repeat`: Continuously repeat pulses
- `num_pulses`: Number of pulses to generate (-1 for infinite)

## Example Flowgraph

A typical flowgraph for channel sounding might include:

1. **Delta Pulse Source** → Generates the test pulse
2. **UHD/USRP Sink** or **Pluto SDR Sink** → Transmits the pulse
3. **UHD/USRP Source** or **Pluto SDR Source** → Receives the signal
4. **QT GUI Time/Freq Sink** → Visualizes the received signal

## Troubleshooting

### Module not found in GRC

If the block doesn't appear in GRC:
1. Verify installation: `gnuradio-config-info --prefix`
2. Check that the block YAML is in the correct location
3. Restart GRC
4. Check GRC preferences for block paths

### Import errors

If you get import errors in Python:
1. Ensure the module is installed: `python3 -c "from delta_pulse import delta_pulse_source"`
2. Check Python path includes GNU Radio modules
3. Verify GNU Radio installation

## License

GPL-3.0-or-later

## Author

Created for delta pulse generation and SDR channel sounding applications.

