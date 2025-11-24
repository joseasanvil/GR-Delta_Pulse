#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GNU Radio block for generating delta-like pulses for SDR channel sounding.

This block generates a delta-like pulse using an OFDM-style IFFT approach,
suitable for channel estimation with SDRs like the Pluto SDR.
"""

import numpy as np
from gnuradio import gr
from .deltaPulse import sdr_delta_pulse


class delta_pulse_source(gr.sync_block):
    """
    GNU Radio source block that generates delta-like pulses for channel sounding.

    This block generates a delta-like pulse periodically. The pulse is created
    using an IFFT of all ones in frequency domain, optionally windowed and centered.

    Input: None (source block)
    Output: Complex-valued samples (complex64)
    """

    def __init__(self, pulse_length=1024, amplitude=0.8, window=True, 
                 center=True, repeat=True, num_pulses=-1):
        """
        Parameters:
            pulse_length (int): Number of samples in the pulse (default: 1024)
            amplitude (float): Output amplitude (keep <= 1.0 for SDRs) (default: 0.8)
            window (bool): Apply Hann window to reduce ringing (default: True)
            center (bool): Center the pulse in the array (default: True)
            repeat (bool): If True, repeat pulses continuously (default: True)
            num_pulses (int): Number of pulses to generate (-1 for infinite) (default: -1)
        """
        gr.sync_block.__init__(
            self,
            name='delta_pulse_source',
            in_sig=None,
            out_sig=[np.complex64]
        )
        
        self.pulse_length = int(pulse_length)
        self.amplitude = float(amplitude)
        self.window = bool(window)
        self.center = bool(center)
        self.repeat = bool(repeat)
        self.num_pulses = int(num_pulses)
        
        # Generate the pulse once
        self.pulse = sdr_delta_pulse(
            N=self.pulse_length,
            amplitude=self.amplitude,
            window=self.window,
            center=self.center
        )
        
        # State tracking
        self.pulse_index = 0
        self.pulses_generated = 0
        self.in_pulse = False
        
        # Calculate samples between pulses (guard interval)
        # For now, we'll output pulses back-to-back, but you can add spacing
        self.samples_between_pulses = 0

    def work(self, input_items, output_items):
        """
        Generate output samples.
        """
        out = output_items[0]
        noutput_items = len(out)
        out_idx = 0
        
        # Check if we should stop generating pulses
        if self.num_pulses > 0 and self.pulses_generated >= self.num_pulses:
            # Fill remaining with zeros
            out[:] = 0.0
            return noutput_items
        
        while out_idx < noutput_items:
            # Check if we need to start a new pulse
            if not self.in_pulse:
                if self.repeat or self.pulses_generated < self.num_pulses or self.num_pulses < 0:
                    self.in_pulse = True
                    self.pulse_index = 0
                    self.pulses_generated += 1
                else:
                    # Fill remaining with zeros
                    out[out_idx:] = 0.0
                    break
            
            if self.in_pulse:
                # Output pulse samples
                samples_to_copy = min(self.pulse_length - self.pulse_index, 
                                     noutput_items - out_idx)
                out[out_idx:out_idx + samples_to_copy] = \
                    self.pulse[self.pulse_index:self.pulse_index + samples_to_copy]
                
                self.pulse_index += samples_to_copy
                out_idx += samples_to_copy
                
                # Check if pulse is complete
                if self.pulse_index >= self.pulse_length:
                    self.in_pulse = False
                    self.pulse_index = 0
                    
                    # Add guard interval (zeros) between pulses if specified
                    if self.samples_between_pulses > 0:
                        guard_samples = min(self.samples_between_pulses, 
                                          noutput_items - out_idx)
                        out[out_idx:out_idx + guard_samples] = 0.0
                        out_idx += guard_samples
                        self.samples_between_pulses -= guard_samples
            else:
                # Fill with zeros
                out[out_idx] = 0.0
                out_idx += 1
        
        return out_idx

