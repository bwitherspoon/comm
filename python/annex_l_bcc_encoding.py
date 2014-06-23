#!/usr/bin/env python

# Annex L tables
tables = {
    # Message for the BCC example

    # Frequency domain representation of the short sequences

    # One period of IFFT of the short sequences

    # Time domain representation of the short sequence

    # Frequency domain representation of the long sequences

    # Time domain representation of the long sequence

    # Bit assignment for SIGNAL field
    'L7' : [0x00, 0x0C, 0x8D],
    # SIGNAL field bits after encoding
    'L8' : [0x00, 0x0E, 0x7C, 0x40, 0x85, 0x8B],
    # SIGNAL field bits after interleaving

    # Frequency domain representation of SIGNAL field

    # Frequency domain representation of SIGNAL field with pilots inserted

    # Time domain representation of SIGNAL field

    # The DATA bits before scrambling
    #'L13' : [0x00, 0x00, 0x04,
    #         0x02, 0x00, 0x2E,
    #         0x00, 0x60, 0x08,
    #         0xCD, 0x37, 0xA6,
    #         0x00, 0x20, 0xD6,
    #         0x01, 0x3c, 0xF1,
    #         0x00, 0x60, 0x08,
    #         0xAD, 0x3B, 0xAF,
    #         0x00, 0x00, 0x4A,
    #         0x6F, 0x79, 0x2C],
    'L13' : [0b00000000, 0b00000000, 0b00100000,
             0b01000000, 0b00000000, 0b01110100,
             0b00000000, 0b00000110, 0b00010000,
             0b10110011, 0b11101100, 0b01100101,
             0b00000000, 0b00000100, 0b01101011,
             0b10000000, 0b00111100, 0b10001111,
             0b00000000, 0b00000110, 0b00010000,
             0b10110101, 0b11011100, 0b11110101,
             0b00000000, 0b00000000, 0b01010010,
             0b11110110, 0b10011110, 0b00110100],
    # Scrambling sequence for seed 1011101
    'L14' : [0b01101100, 0b00011001, 0b10101001,
             0b11001111, 0b01101000, 0b01010101,
             0b11110100, 0b10100011, 0b01110001],
    # The DATA bits after scrambling
    'L15' : [0x6C, 0x19, 0x89,
             0x8F, 0x68, 0x21,
             0xF4, 0xA5, 0x61,
             0x4F, 0xD7, 0xAE,
             0x24, 0x0C, 0xF3,
             0x3A, 0xE4, 0xBC,
             0x53, 0x98, 0xC0,
             0x1E, 0x35, 0xB3,
             0xE3, 0xF8, 0x25,
             0x60, 0xD6, 0x25]
}

def octet_to_bin(val):
    '''
    Convert an integer representing an octet to a binary string
    '''
    s = bin(val & 0xFF)
    s = s.lstrip('-b0')
    return s.zfill(8)

def octet_to_hex(val):
    '''
    Convert an integer representing an octet to a hexadecimal string
    '''
    s = hex(val & 0xFF)
    s = s.lstrip('-0x')
    return s.zfill(2)

def octets_to_readmemb(octets):
    '''
    Convert octets to readmemb format

    octets: an iterable of integers representing octets
    '''
    l = []
    for o in octets:
        s = octet_to_bin(o)
        s = '_'.join((s[:4], s[4:]))
        l.append(s)
    return '_'.join(l)[::-1]

def table_to_readmemb(table, width):
    '''
    Convert a table to readmemb format

    Tables with a length not equal to a multiple of width are truncated.
    '''
    # Split the table to words of width bytes
    split = [table[width*i:width*(i+1)] for i in xrange(len(table)/width)]
    words = []
    for w in split:
        words.append(octets_to_readmemb(w))
    return '\n'.join(words)

def main():
    import sys
    from optparse import OptionParser

    parser = OptionParser()
    parser.add_option('-w', '--width', type='int', default=3,
                      help='the data width in bytes')
    parser.add_option('-t', '--table', type='string',
                      help='the table to print')

    (opts, _) = parser.parse_args()

    if not opts.table:
        parser.print_help()
        raise SystemExit(1)

    try:
        table = tables[opts.table]
    except KeyError:
        sys.stderr.write('Table not found\n')
        raise SystemExit(1)

    print(table_to_readmemb(table, opts.width))

if __name__ == '__main__':
    main()
