#include <Python.h>
#include "numpy/arrayobject.h"

#include "Vpcb.h"
#include "SpCommon.h"
#include "SpTraceVcdC.h"

// these are the HI states
typedef enum {
    IDLE=0,
    SETEP=1,
    SETREG=2,
    SETRVAL=  3,
    RDDATA = 4,
    RESETRVAL = 5,
    GETRVAL = 6,
    RDTC = 7,
    WRDATA = 8
} HI_STATE;


Vpcb *tb = NULL;
SpTraceVcdCFile *tfp = NULL;
unsigned int main_time = 0;	// Current simulation time
bool trace = true;

int cycle_timeout=1000;

#define CHECK_INIT   if(tb == NULL) { PyErr_SetString(PyExc_Exception, "You have not initialized this sim yet.  Run init() function"); return NULL; }

#define dprintf(...) printf(__VA_ARGS__)

// 10 main time = 1 ns
double sc_time_stamp () {	// Called by $time in Verilog
    return main_time;
}

// clocks
// if_clock = 48mhz 20.83 ns cycle
// sdram_clki = 100mhz = 10ns cycle
// clockb = unused
// CLKC = 25mhz = 40 ns cycle


void advance() {
  bool eval=false;  
  if (main_time % 104 == 0) {
    tb->if_clock = !tb->if_clock;
    eval=true;
  }
  if (main_time % 50 == 0) {
    tb->CLKA = !tb->CLKA;
    eval=true;
  }
  if (main_time % 200 == 0) {
    tb->CLKC = !tb->CLKC;
    eval=true;
  }
  if (eval) {
    tb->eval();	      // Evaluate model
  }
  if(trace) tfp->dump (main_time); // Create waveform trace for this timestamp
  ++main_time;		// Time passes...
}

/**
 * wait for the interface clock to cycle.
 * if the clock is already on the requsted cycle this will wait
 * until the rise of the next cycle.
 *
 * rise=true for high false for low
 **/
void iclock_cycle (bool rise=true) {
  if (tb->if_clock == (rise?1:0)) {
   iclock_cycle(!rise); // now clock is low
  }
  tb->eval(); // always call at beginning
  while ( tb->if_clock != rise ) advance();
}

void iwait(int cycles) {    
    while (cycles--)
        iclock_cycle();
}

/**
 * Wait until rdy is high then send a write w/ the data.
 **/
int single_write(int val) {
    // takes a few clock cycles
    iwait(4);
    int wait=0;
    do {
     iclock_cycle(); 
     if (++wait > cycle_timeout) {
      dprintf ( "Waited %d cycles\n", wait );
      return -1;
     }
    } while ( !tb->rdy );
    tb->ctl = 2; // rdwr_b = 1
    tb->we = 1;
    tb->datain = val;
    iclock_cycle();
    tb->we = 0;
    tb->ctl = 0;
    tb->datain = 0;
    iwait(5);
    return 0;
}

/**
 *	Send a read.  Wait until a rdy comes back with the data
 **/

int single_read(int* val) {
    
    iwait(5);

//    state 0
    tb->ctl = 2;
    iclock_cycle();

//   state 1
    int wait=0;
    int rdy_s, dataout_s;
    tb->ctl = 0;
    do { 
     rdy_s = tb->rdy;
     dataout_s = tb->dataout;
     iclock_cycle();
     if (++wait > cycle_timeout) {
      dprintf ( "Waited %d cycles\n", wait );
      return -1;
     }
    } while (!rdy_s); 

    *val = dataout_s;
    iwait(5);
    return 0;
}


/**
 * waits until ready goes high.  
 **/
void fifo_read(int count=1,uint16_t *buf=NULL) {

    iwait(5);
    int read = 0;
    int state = 0;
    bool exit=false;

    // idle state
    tb->ctl = 0;

    int dataout_s=0;
    int rdy_s=0;


// gpif state machine
    int wait=0;
    while ( !exit ) {
        dataout_s = tb->dataout;
        rdy_s = tb->rdy; 

        iclock_cycle(); // brings us to the next state

  
        switch ( state ) {
           case 0:
                tb->ctl = 6; // rd+ctl2
                if ( rdy_s ) { //tb->rdy ) {
                    state = 1;
                } else {
                    ++wait;
                    if (wait>cycle_timeout) {
                        dprintf ( "Waited %d cycles.. Timeout\n", wait );
                        exit=true;
                    }
                }
                break;
            case 1:
                tb->ctl = 6; // rd+ctl2
                if ( !rdy_s || read>=count ) {
                   state = 2; 
                }
                buf[read++] = dataout_s;
                break;
            case 2:
            case 3:
            case 4:
            case 5:
                tb->ctl = 4; // ctl2
                if (rdy_s) {
                    state = 1;
                } else {
                    state = state+1;
                }
                break;
            case 6:
               tb->ctl = 4; // ctl2
               if ( read >= count ) {
                 exit=true; 
               } else {
                 state = 0;
               }
               break;
            default:
                assert ( NULL );
        }
       
    }
    tb->ctl=0;
    
}

void set_addrs(int ep_addr, int reg_addr) {
    tb->state = SETEP;
    single_write(ep_addr);
    
    tb->state = SETREG;
    single_write(reg_addr);
}



static PyObject *init(PyObject *self, PyObject *args) {
  const char *filename=NULL;

  if (!PyArg_ParseTuple(args, "|s", &filename)) {
    PyErr_SetString(PyExc_Exception, "Optional argument should be a string specify a the vcd trace filename");
    return NULL;
  }
    
  tb   = new Vpcb("tb");	// Create instance of module
  Verilated::debug(0);

  trace = (filename != NULL);
  
  if(trace) {
    trace = true;
    Verilated::traceEverOn(true);	// Verilator must compute traced signals
    tfp = new SpTraceVcdCFile;
    tb->trace (tfp, 99);	// Trace 99 levels of hierarchy
    tfp->open (filename);	// Open the dump file
  }
  Py_RETURN_NONE; 
}

static PyObject *set(PyObject *self, PyObject *args) {
  int val,ep_addr,reg_addr;

  CHECK_INIT;

  if (!PyArg_ParseTuple(args, "iii", &ep_addr,&reg_addr, &val)) {
    PyErr_SetString(PyExc_Exception, "Arguments are ep_addr, reg_addr, val (ints)");
    return NULL;
  }

  set_addrs(ep_addr,reg_addr);
  tb->state = SETRVAL;
  int ret=single_write(val);
  tb->state= IDLE;
  iclock_cycle();

  if (ret<0) {
    PyErr_SetString(PyExc_Exception, "Write Didn't Work" );
    return NULL;
  }

  Py_RETURN_NONE; 
}




static PyObject *get(PyObject *self, PyObject *args) {
  int ep_addr;
  int reg_addr;
  int val;

  CHECK_INIT

  if (!PyArg_ParseTuple(args, "ii", &ep_addr, &reg_addr) ) {
    PyErr_SetString(PyExc_Exception, "Expected arguments: ep-addr: Integer, reg_addr: Integer");
    return NULL;
  }
  
  set_addrs(ep_addr,reg_addr);
  tb->state = GETRVAL;
  int ret=single_read(&val);
  tb->state = IDLE;
  iclock_cycle();

  if (ret < 0) {
    PyErr_SetString(PyExc_Exception, "Read didn't work" );
    return NULL;
  }
  
  return Py_BuildValue("i", val);
}

static PyObject *read(PyObject* self, PyObject *args ) {
    int term,addr,length;
    PyObject* pyObj;
    unsigned char* data;
     if (!PyArg_ParseTuple ( args, "iiO", &term,&addr,&pyObj )) {
     PyErr_SetString ( PyExc_Exception, "read ( term, addr, data )" );
     return NULL;
    }

   if(PyString_Check(pyObj)) {
    length = PyString_Size(pyObj);
    data = (unsigned char*) PyString_AsString(pyObj);
  } else if(PyArray_Check(pyObj)) {
    length = PyArray_NBYTES(pyObj);
    data = (unsigned char*) PyArray_DATA(pyObj);
  } else {
    PyErr_SetString(PyExc_Exception, "Second argument must be data as a string object or numpy array");
    return NULL;
  }

  // see global interpreter lock http://docs.python.org/api/threads.html#l2h-911
  int result;
  Py_BEGIN_ALLOW_THREADS

  set_addrs(term,addr);

  // read blocks of data in 512 byte packets (256 tc)
  int total_tc=length/2;
  int transferred=0;
  int cur_transfer = total_tc <= 256 ? total_tc : 256;

  // initial 
  tb->state = RDTC;
  single_write(cur_transfer); 

  tb->state = RDDATA;
  while ( transferred < total_tc ) {
    cur_transfer = total_tc - transferred <= 256 ? total_tc-transferred : 256 ; 

    if (cur_transfer < 256 && transferred>0) {
        tb->state = RDTC;
        single_write( cur_transfer );
        tb->state = RDDATA; 
    }

    fifo_read(cur_transfer,(uint16_t*)(data+transferred*2));
    transferred+=cur_transfer;
  }

  tb->state = IDLE;
  iclock_cycle();
 
  Py_END_ALLOW_THREADS

//  CHECK_DEVIF_RET(result);

  Py_RETURN_NONE;
  
}


static PyObject *write (PyObject *self, PyObject *args) {

  // no ep's implemented right now.
  //
  iwait(50);

  Py_RETURN_NONE;
}



static PyObject *time(PyObject *self, PyObject *args) {
  return Py_BuildValue("i", main_time);
}


static PyObject *clk_rise(PyObject *self, PyObject *args) {
  CHECK_INIT
  iclock_cycle();
  Py_RETURN_NONE;
}

static PyObject *clk_fall(PyObject *self, PyObject *args) {
  CHECK_INIT
  iclock_cycle(false);
  Py_RETURN_NONE;
}

static PyObject *close(PyObject *self, PyObject *args) {
  CHECK_INIT
  tb->final();
  delete tb;
  if(trace) {
    tfp->close();
    delete tfp;
  }
  tb = NULL;
  tfp = NULL;
  Py_RETURN_NONE; 
}


static PyObject *set_timeout(PyObject *self, PyObject *args) {

  int timeout;
    
  CHECK_INIT
  
  if (!PyArg_ParseTuple(args, "i", &timeout) ) {
    PyErr_SetString(PyExc_Exception, "Expected arguments: timeout: Integer");
    return NULL;
  }

  if (timeout < 1) {
    PyErr_SetString(PyExc_Exception, "timeout must be >= 1" );
    return NULL;
  }
  cycle_timeout=timeout;

  Py_RETURN_NONE;
}


/*************************************  Vtb extension module ****************/
static PyMethodDef Vpcb_methods[] = {
  {"init", init, METH_VARARGS,"Creates an instance of the simulation." },
  {"set",  set,  METH_VARARGS,"Sets the specified port to specified value." },
  {"get",  get,  METH_VARARGS,"Gets the current value of the specified port." },
  {"read", read, METH_VARARGS,"Read fifo data from a register."},
  {"write",write,METH_VARARGS,"Write fifo data to a register."},
  {"time", time, METH_NOARGS, "Gets the current time of the simulation." },
  {"clk_rise", clk_rise, METH_NOARGS, "Advances sim to next rising clk edge"},
  {"clk_fall", clk_fall, METH_NOARGS, "Advances sim to next falling clk edge"},
  {"set_timeout", set_timeout, METH_VARARGS, "Set the number of cycles before a read/write times out." },
  {"close",  close,  METH_NOARGS, "Ends simulation & deletes all sim objects." },
  {NULL}  /* Sentinel */
};

#ifndef PyMODINIT_FUNC	/* declarations for DLL import/export */
#define PyMODINIT_FUNC void
#endif
PyMODINIT_FUNC initVpcb(void) {
    PyObject* m;

    m = Py_InitModule3("Vpcb", Vpcb_methods,
                       "Ubixum test device.");

    import_array(); // necessary to use numpy arrays
}
