import numpy as np

def sdr_delta_pulse(N=1024, amplitude=0.8, window=True, center=True):
    """
    Generate an SDR-safe delta-like pulse using an OFDM-style IFFT.

    Parameters:
        N (int): Number of samples
        amplitude (float): Output amplitude (keep <= 1.0 for Pluto SDR)
        window (bool): Apply Hann window to reduce ringing
        center (bool): If True, center the pulse in the array (recommended for windowing)

    Returns:
        np.ndarray: Complex-valued delta-like pulse
    """

    # Frequency domain: all ones => impulse in time domain
    X = np.ones(N, dtype=np.complex64)

    # Time-domain impulse (delta at index 0)
    x = np.fft.ifft(X)

    # Center the pulse if requested (moves delta to middle of array)
    if center:
        x = np.fft.fftshift(x)

    # Normalize amplitude
    x = x / np.max(np.abs(x)) * amplitude

    # Optional window to smooth edges
    if window:
        w = np.hanning(N)
        x = x * w
        # Renormalize after windowing to maintain desired amplitude
        max_val = np.max(np.abs(x))
        if max_val > 0:
            x = x / max_val * amplitude

    return x.astype(np.complex64)

