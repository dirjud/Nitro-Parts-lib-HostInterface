"""
    This test shows how to use the 
    simulated device the same way you use a real Nitro device.
"""
import nitro

import numpy

d=nitro.UserDevice('./Vpcb.so', ['trace.vcd'])

d.set(0,1,10)
print "Led Value:", d.get(0,1)

print "Button 1 val:", d.get(0,0)

print "Set The Slow Writer.."

d.set(0,2,0xab)

print "Counter Get: ", d.get(0,4)

n=numpy.zeros(10,dtype=numpy.uint16)
d.read(0,3,n)
print "Counter Fifo:", n

for x in range(6):
    print "Counter Get:",d.get(0,4)

n=numpy.zeros(8,dtype=numpy.uint16)
d.read(0,3,n)
print "Counter Fifo:", n 


c=d.get(0,4);
readsize=513
n=numpy.zeros(readsize,dtype=numpy.uint16)
d.read(0,3,n)
print "Last Read ", n[-1], "Expecting", c+readsize


print "Slow Writer Value %02x" % d.get(0,2)

d.close();

