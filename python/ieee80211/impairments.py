'''
'''

from numpy import arange, exp, pi

def add_frequency_offset(a, f, fs=20e6):
    '''
    Add a constant frequency offset
    
    a: an array like object, modified in place
    f: frequency offset
    fs: sampling frequency
    '''
    df = f/fs
    n = arange(a.size)
    offset = exp(2j*pi*df*n)
    a *= offset

def awgn(x):
    pass
