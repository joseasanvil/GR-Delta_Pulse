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

if __name__ == "__main__":
    # Test the function
    pulse = sdr_delta_pulse(N=1024, amplitude=0.8, window=True)
    print(f"Pulse shape: {pulse.shape}")
    print(f"Max amplitude: {np.max(np.abs(pulse)):.6f}")
    print(f"First 5 samples: {pulse[:5]}")
    print(f"Center 5 samples: {pulse[len(pulse)//2-2:len(pulse)//2+3]}")
    
    # Concatenate several
    pulse = np.concatenate([pulse, pulse])

    # Plot the pulse in time domain
    import matplotlib.pyplot as plt

    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    
    # Time domain - magnitude
    axes[0, 0].plot(np.abs(pulse))
    axes[0, 0].set_title('Time Domain - Magnitude')
    axes[0, 0].set_xlabel('Sample')
    axes[0, 0].set_ylabel('Amplitude')
    axes[0, 0].grid(True)
    
    # Time domain - real and imaginary
    axes[0, 1].plot(np.real(pulse), label='Real', alpha=0.7)
    axes[0, 1].plot(np.imag(pulse), label='Imaginary', alpha=0.7)
    axes[0, 1].set_title('Time Domain - Real & Imaginary')
    axes[0, 1].set_xlabel('Sample')
    axes[0, 1].set_ylabel('Amplitude')
    axes[0, 1].legend()
    axes[0, 1].grid(True)
    
    # Frequency domain - magnitude
    freq_response = np.fft.fft(pulse)
    freqs = np.fft.fftfreq(len(pulse))
    axes[1, 0].plot(freqs, np.abs(freq_response))
    axes[1, 0].set_title('Frequency Domain - Magnitude')
    axes[1, 0].set_xlabel('Normalized Frequency')
    axes[1, 0].set_ylabel('Magnitude')
    axes[1, 0].grid(True)
    
    # Frequency domain - dB
    axes[1, 1].plot(freqs, 20 * np.log10(np.abs(freq_response) + 1e-10))
    axes[1, 1].set_title('Frequency Domain - Magnitude (dB)')
    axes[1, 1].set_xlabel('Normalized Frequency')
    axes[1, 1].set_ylabel('Magnitude (dB)')
    axes[1, 1].grid(True)
    
    plt.tight_layout()
    plt.show()
    
    