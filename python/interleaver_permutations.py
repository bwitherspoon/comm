#!/usr/bin/env python

def iperm(k):
    '''
    i = (N_cbps/16)(k mod 16) + floor(k/16)
    '''
    raise NotImplementedError

def jperm(i, s=2):
    '''
    j = s * floor(i/s) + (i + N_cbps - floor(16*i/N_cbps)) mod 16
    s = max(N_bpsc/2, 1)
    '''
    s = int(s)
    if s not in range(1, 4):
        raise ValueError
    if s == 3:
        Ncbps = 288
    elif s == 2:
        Ncbps = 192
    else:
        return i
    return s * (i//s) + (i + Ncbps - (16*i)//Ncbps) % s


if __name__ == "__main__":
    print("Reference:")
    for i in range(192):
        row = i // 16
        col = i % 16
        if col == 0:
            print("\n{:X}:".format(row)),
        print("{:2X}".format(col)),
    print("\n")

    print("Column permutation (j) for 16-QAM:")
    for i in range(192):
        j = jperm(i, 2)
        row = j // 12
        col = j % 12
        if i % 12 == 0:
            print("\n{:X}:".format(row)),
        print("{:2X}".format(col)),
    print("\n")

    print("Column permutation (j) for 64-QAM:")
    for i in range(288):
        j = jperm(i, 3)
        row = j // 18
        col = j % 18
        if i % 18 == 0:
            print("\n{:X}:".format(row)),
        print("{:2X}".format(col)),
    print("\n")
