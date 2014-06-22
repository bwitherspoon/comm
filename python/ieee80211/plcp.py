'''
18.3 OFDM PLCP sublayer
'''

from numpy import array, complex, hstack, roll, sqrt, uint8, zeros
from numpy.fft import ifft

sts = sqrt(13.0/6.0)*array([0, 0, 1+1j, 0, 0, 0, -1-1j, 0, 0, 0, 1+1j, 0, 0, 0, -1-1j, 0, 0, 0, -1-1j, 0, 0, 0, 1+1j, 0, 0, 0, 0, 0, 0, 0, -1-1j, 0, 0, 0, -1-1j, 0, 0, 0, 1+1j, 0, 0, 0, 1+1j, 0, 0, 0, 1+1j, 0, 0, 0, 1+1j, 0, 0])
lts = array([1, 1, -1, -1, 1, 1, -1, 1, -1, 1, 1, 1, 1, 1, 1, -1, -1, 1, 1, -1, 1, -1, 1, 1, 1, 1, 0, 1, -1, -1, 1, 1, -1, 1, -1, 1, -1, -1, -1, -1, -1, 1, 1, -1, -1, 1, -1, 1, -1, 1, 1, 1, 1])

_pilot_subcarriers = [-21, -7, 7, 21]
        
_20mhz_rate_field_map = {  6 : [1, 1, 0, 1], 
                           9 : [1, 1, 1, 1],
                          54 : [0, 0, 1, 1] }
        
def _subcarrier_to_offset(k):
    '''
    Convert a logical subcarrier number 0 to 47 index into a frequency offset
    index -26 to 26, while skipping the pilot subcarrier locations and the DC
    carrier
    
    Equation 18-23
    '''
    if k < 0 or k > 47:
        raise ValueError("Subcarrier number must be within the range 0 to 47")
    elif k < 5:
        i = k - 26
    elif k < 18:
        i = k - 25
    elif k < 24:
        i = k - 24
    elif k < 30:
        i = k - 23
    elif k < 43:
        i = k - 22
    else:
        i = k - 21
    return i

def _apply_window(a):
    a[0]  = 0.5 * a[0]
    a[-1] = 0.5 * a[-1]
    return a

def _create_sts():
    '''
    Create an 802.11a OFDM short training sequence
    '''
    # See Table L-2
    s = zeros(64, dtype=complex)
    s[-24] =  1+1j
    s[-20] = -1-1j
    s[-16] =  1+1j
    s[-12] = -1-1j
    s[-8]  = -1-1j
    s[-4]  =  1+1j
    s[4]   = -1-1j
    s[8]   = -1-1j
    s[12]  =  1+1j
    s[16]  =  1+1j
    s[20]  =  1+1j
    s[24]  =  1+1j 
    s = s * sqrt(13.0/6.0) 
    
    # See Table L-3
    S = ifft(s)
    
    # Extended periodically for 161 samples
    # See Table L-4
    sts = hstack((S, S, S[:33]))
    
    # Apply windowing function
    _apply_window(sts)
    
    return sts

def _create_lts():
    '''
    Create an 802.11a OFDM long training sequence
    '''
    # See Table L-5
    l = zeros(64)
    l[1:27] = [1,-1,-1, 1, 1,-1, 1,-1, 1,-1,-1,-1,-1,-1, 1, 1,-1,-1, 1,-1, 1,-1, 1, 1, 1, 1]
    l[-26:] = [1, 1,-1,-1, 1, 1,-1, 1,-1, 1, 1, 1, 1, 1, 1,-1,-1, 1, 1,-1, 1,-1, 1, 1, 1, 1]
    
    # See Table L-6
    L = ifft(l)
    
    # Extended periodically twice and add cyclic prefix
    # See Table L-6
    lts = hstack((L[-32:], L, L, L[0])) 
    
    # Apply windowing function
    _apply_window(lts)
    
    return lts

def create_preamble():
    '''
    Create a 802.11a OFDM PLCP preamble
    
    Section 18.3.3
    '''
    
    # Generate short and long training sequence
    sts = _create_sts()
    lts = _create_lts()
    
    # Overlap and add STS and LTS
    return hstack((sts[:-1], sts[-1] + lts[0], lts[1:]))

def create_header(rate, length):
    '''
    '''
    pass

def create_signal_field(plcp_header):
    '''
    Create a 802.11a OFDM SIGNAL field symbol
    
    Section 18.3.4
    '''
    pass

class convolutional_encoder(object):
    '''
    '''
    pass

class scrambler(object):
    '''
    18.3.5.5 PCLP DATA scrambler and descrambler
    
    S(x) = x^7 + x^4 + 1
    '''
    def __init__(self, seed=[1, 1, 1, 1, 1, 1, 1]):
        self._reg = array([x % 2 for x in seed], dtype=uint8)
    
    def __call__(self, din):
        dout = self._reg[6] ^ self._reg[3]
        self._reg = roll(self._reg, 1)
        self._reg[0] = dout
        return dout ^ din

if __name__ == "__main__":
    
    expected = [ 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0,
                 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 
                 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 
                 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 
                 1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 
                 1, 0, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 
                 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 
                 1, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1 ]
