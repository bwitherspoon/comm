'''
'''

import numpy as np

def sts_correlation(r, n=16):
    '''
    Compute the autocorrelation of the short training symbol
    
    P(d) = \sum_{m=0}^{L-1} r^*_{d-m}r_{d-m-L}
    
    P(d) = P(d - 1) + r_{d}^*r_{d-L} - r_{d-L}^*r_{d-2L}
    ''' 
    # S(d) = S(d-1) + conj(r(d)) * r(d-L)
    s = r[n:].conj() * r[:-n]
    s.cumsum(out=s)
    # P(d) = S(d) - S(d-L)
    s[n:] = s[n:] - s[:-n]
    # Only return where correlation window fully overlaps signal
    return s[n-1:]

def sts_energy(r, n=16):
    '''
    Compute the energy in one eighth of the short training symbol
    
    R(d) = \sum_{m=0}^{L-1} |r_{d-m}|^2
    
    R(d) = R(d-1) + r_{d}^*r_{d} - r_{d-L}^*r_{d-L}
    '''
    # S(d) = S(d-1) + conj(r(d)) * r
    s = r[n:].conj() * r[n:]
    s.cumsum(out=s)
    # R(d) = S(d) - S(d-L)
    s[n:] = s[n:] - s[:-n]
    # Only return where correlation window fully overlaps signal
    return s[n-1:]

def sts_timing_metric(r, n=16):
    '''
    M(d) = \frac{|P(d)|^2}{(R(d))^2}
    '''
    p = sts_correlation(r, n)
    r = sts_energy(r, n)
    # FIXME use eigsum
    m = np.abs(p)**2 / r**2
    # FIXME return dtype as real only
    return m

def estimate_cfo(p, Ts=0.8e-6):
    '''
    Estimate the course frequency offset from the STS correlation
    '''
    return np.angle(p) / (2*np.pi*Ts)
