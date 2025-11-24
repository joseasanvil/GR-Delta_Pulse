# OFDM Channel Estimation using SDRs

This repository contains tools and modules for OFDM channel estimation using Software Defined Radios (SDRs), including a GNU Radio Out-of-Tree (OOT) module for delta pulse generation.

## Contents

- **gr-delta_pulse**: GNU Radio OOT module for generating delta-like pulses for channel sounding
- **MATLAB**: MATLAB scripts and examples for OFDM channel estimation
- **python**: Python utilities for delta pulse generation

---

## Installing the GNU Radio OOT Module (gr-delta_pulse)

The `gr-delta_pulse` module provides a Delta Pulse Source block for GNU Radio Companion, useful for channel sounding and estimation with SDRs like the Pluto SDR.

### Prerequisites

- **GNU Radio 3.8 or later**
- **CMake 3.10 or later**
- **Python 3.x** with NumPy
- **Conda environment** (recommended) with GNU Radio installed

### Installation

1. **Create build directory:**
   ```bash
   cd gr-delta_pulse
   mkdir -p build
   cd build
   ```

2. **Configure with CMake:**
   ```bash
   cmake ..
   ```

3. **Build the module:**
   ```bash
   make
   ```

4. **Install the module:**
   ```bash
   sudo make install
   ```

The module should now be available in GNU Radio Companion under the category `[delta_pulse]`.

---

## Usage

### In GNU Radio Companion (GRC)

1. **Open GNU Radio Companion** (make sure you're using the conda environment if applicable)

2. **Find the block**: The block should appear in the block tree under:
   - Category: `[delta_pulse]`
   - Block: `Delta Pulse Source`

3. **Add to flowgraph**: Drag the block into your flowgraph

4. **Configure parameters**:
   - **Pulse Length (samples)**: Number of samples in each pulse (default: 1024)
   - **Amplitude**: Output amplitude, keep ≤ 1.0 for SDRs (default: 0.8)
   - **Apply Hann Window**: Apply windowing to reduce ringing (default: True)
   - **Center Pulse**: Center the pulse in the array (default: True)
   - **Repeat Pulses**: Continuously repeat pulses (default: True)
   - **Number of Pulses**: Number of pulses to generate, -1 for infinite (default: -1)

5. **Connect and run**: Connect the output to your SDR sink or visualization blocks

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

### Example Flowgraph

A typical channel sounding flowgraph might include:

1. **Delta Pulse Source** → Generates the test pulse
2. **Throttle** → Controls sample rate (if not using hardware)
3. **UHD/USRP Sink** or **Pluto SDR Sink** → Transmits the pulse
4. **UHD/USRP Source** or **Pluto SDR Source** → Receives the signal
5. **QT GUI Time/Freq Sink** → Visualizes the received signal

---

## Block Description

### Delta Pulse Source

The Delta Pulse Source block generates a delta-like pulse suitable for channel sounding. The pulse is created using an OFDM-style IFFT approach:

1. Creates a frequency-domain signal with all ones
2. Performs an IFFT to get a time-domain impulse
3. Optionally centers the pulse in the time array
4. Optionally applies a Hann window to reduce spectral leakage
5. Normalizes to the specified amplitude

**Output**: Complex-valued samples (complex64)

**Parameters**:
- `pulse_length`: Number of samples in each pulse
- `amplitude`: Peak amplitude of the pulse (recommended ≤ 1.0 for SDRs)
- `window`: Apply Hann windowing to reduce ringing
- `center`: Center the pulse in the time array
- `repeat`: Continuously repeat pulses
- `num_pulses`: Number of pulses to generate (-1 for infinite)
