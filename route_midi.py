#routes midi from a midi port to gameboy
 
import mido
import serial
 
 
out_port = port = serial.Serial('COM4', 9600, timeout = 0.01)

inputs = mido.get_input_names()
str_inputs = '\n'.join("{}: {}".format(n, inp) for n, inp in enumerate(inputs))
print("choose a midi input\n" + str_inputs)
choice = int(input("\n> "))
in_port = mido.open_input(inputs[choice]) #connect to midi port
print("connected to port!")

for msg in in_port: #recieve messages, send them to gameboy over serial connection
    to_send = bytes(msg.bytes())
    #print(to_send)
    out_port.write(to_send)
