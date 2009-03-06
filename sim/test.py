"""
    This test shows how to use the 
    simulated device the same way you use a real Nitro device.
"""
from nitro.devices.ubiDevice import ubiDevice

import Vpcb
import numpy

Vpcb.init('trace.vcd')

d=ubiDevice(sim=Vpcb)

d.set(0,1,10)
print "Led Value:", d.get(0,1)

print "Button 1 val:", d.get(0,0)

print "Set The Slow Writer.."

d.set(0,2,0xab)

print "Counter Get: ", d.get(0,4)

n=numpy.zeros(10,dtype=numpy.uint16)
d.read(0,3,data=n)
print "Counter Fifo:", n

for x in range(6):
    print "Counter Get:",d.get(0,4)

print "Counter Fifo:", d.read(0,3,8)

print "Slow Writer Value %02x" % d.get(0,2)

d.close();

