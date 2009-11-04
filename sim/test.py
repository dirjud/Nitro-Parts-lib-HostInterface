"""
    This test shows how to use the 
    simulated device the same way you use a real Nitro device.
"""
import nitro
import Vtb
import numpy
dev = None

def setup():
    global dev
    Vtb.init("test.vcd")
    dev=Vtb.get_dev()
    
    d = {}
    execfile("terminals.py", d)
    dev.set_di(d["di"])


def test_transfer_status():
    """Transfer Status Test
    """
    try:
        dev.set("Fast", 200, 0)
        assert(False, "Transfer Status") # previous statement should have failed
    except:
        pass

    try:
        x = "\x00"  * 10
        dev.read("Fast", 200, x)
        assert(False, "Transfer Status") # previous statement should have failed
    except:
        pass


def test_back_to_back_set():
    """Back-to-Back Set Test
    
    Sets the entire register set and then reads it back to verify back
    to back tests work on both a fast and slow endpoint.
    """

    def test(term, reg):
        xi = numpy.random.randint(low=0x0000, high=0x10000, size=[160]).astype(numpy.uint16)
        for i,x in enumerate(xi):
            dev.set(term, reg + "[%d]"%i, x)

        xo = numpy.zeros_like(xi)
        for i in range(len(xi)):
            xo[i] = dev.get(term, reg + "[%d]"%i)
        print term, reg
        print "xi=", xi
        print "xo=", xo
        assert (xi == xo).all(), "Set/Get Random data test for %s/%s" % (term, reg)
    # test both Fast and Slow endpoint
    test("Fast", "fast_buf")
    test("Slow", "slow_buf")


def test_back_to_back_get():
    """Back-to-Back Get Test
    
    Reads a register many times in a row to verify back-to-back reads
    work for both slow and fast terminals.
    """
    def test(term, reg):
        val = dev.get(term, reg)
        for i in range(10):
            val2 = dev.get(term, reg)
            assert val == val2, "Back to back read %d for %s/%s" % (i, term, reg)
    test("Fast", "fast_reg")
    test("Slow", "slow_reg")
    
def test_set_get():
    """Set/Get Test
    
    Sets then gets a register and verifies with different values for
    both slow and fast terminals.
    """
    def test(term, reg):
        for i in [0xAAAA, 0xFFFF, 0x0000, 0x5555]:
            dev.set(term, reg, i)
            assert i == dev.get(term, reg), "%s/%s set/get test = 0x%x" % (term, reg, i)
    test("Fast", "fast_reg")
    test("Slow", "slow_reg")

def test_write_read():
    """Write/Read test
    Writes a random sequence and then reads it back to verify
    """
    def test(term, reg):
        xi = numpy.random.randint(low=0x0000, high=0x10000, size=[160]).astype(numpy.uint16)
        dev.write(term, reg, xi)
        xo = numpy.zeros_like(xi)
        dev.read(term, reg, xo)
        print term, reg
        print "xi=", xi
        print "xo=", xo
        assert (xi == xo).all(), "Write/Read Random data test for %s/%s" % (term, reg)
    test("Fast", "fast_buf")
    test("Slow", "slow_buf")

def test_recover_from_never_read_ready():
    """Recover From Stalled Get
    Read from the 'NeverReadReady' terminal, which will never return.  The PC
    will timeout.  Then we do another set/get from a valid terminal and to
    make sure the host interface pulls out correctly.

    """
    try:
        dev.get("NeverReadReady", "reg2")
        assert False, "NeverReadReady Returned"
    except:
        dev.set("Fast", "fast_reg", 0xBA98)
        assert dev.get("Fast", "fast_reg") == 0xBA98, "Recovered"

def teardown():
    dev.close();
    Vtb.end()
    
