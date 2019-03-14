#A script to generate 2 look up tables to be used by the game ROM
#The look up tables convert MIDI frequency bytes to bits used by the gameboy's tone registers


NOTE_FREQS = [ #the frequencies that each midi note corresponds to (for middle A = 440.0 hz)
	8.18, 8.66, 9.18, 9.72, 10.3, 10.91, 11.56, 12.25, 12.98, 13.75, 14.57, 
	15.43, 16.35, 17.32, 18.35, 19.45, 20.6, 21.83, 23.12, 24.5, 25.96, 
	27.5, 29.14, 30.87, 32.7, 34.65, 36.71, 38.89, 41.2, 43.65, 46.25, 49.0, 
	51.91, 55.0, 58.27, 61.74, 65.41, 69.3, 73.42, 77.78, 82.41, 87.31, 92.5, 
	98.0, 103.83, 110.0, 116.54, 123.47, 130.81, 138.59, 146.83, 155.56, 164.81, 
	174.61, 185.0, 196.0, 207.65, 220.0, 233.08, 246.94, 261.63, 277.18, 293.66, 
	311.13, 329.63, 349.23, 369.99, 392.0, 415.3, 440.0, 466.16, 493.88, 523.25, 
	554.37, 587.33, 622.25, 659.26, 698.46, 739.99, 783.99, 830.61, 880.0, 932.33, 
	987.77, 1046.5, 1108.73, 1174.66, 1244.51, 1318.51, 1396.91, 1479.98, 1567.98, 
	1661.22, 1760.0, 1864.66, 1975.53, 2093.0, 2217.46, 2349.32, 2489.02, 2637.02, 
	2793.83, 2959.96, 3135.96, 3322.44, 3520.0, 3729.31, 3951.07, 4186.01, 4434.92, 
	4698.64, 4978.03, 5274.04, 5587.65, 5919.91, 6271.93, 6644.88, 7040.0, 7458.62, 
	7902.13, 8372.02, 8869.84, 9397.27, 9956.06, 10548.08, 11175.3, 11839.82, 12543.85
]

def freq_to_bits(freq):
	val = 2048 - (131072/freq) #magic equation to convert freq to tone bits
	rounded = int(round(val)) #bits have to be an int
	if rounded < 0: #get those negative bits outta here
		rounded = 0
	return rounded

	
lo_bits = bytes()
hi_bits = bytes()

for freq in NOTE_FREQS: #convert each freq into bits for gameboy
	bits = freq_to_bits(freq)
	lo = bits & 0xFF
	hi = bits >> 8
	lo_bits += bytes([lo])
	hi_bits += bytes([hi])

with open('midi_lut_lo', 'wb') as lo_f, open('midi_lut_hi', 'wb') as hi_f:
	lo_f.write(lo_bits)
	hi_f.write(hi_bits)
