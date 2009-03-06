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

#define CHECK_INIT   if(tb == NULL) { PyErr_SetString(PyExc_Exception, "You have not initialized this sim yet.  Run init() function"); return NULL; }


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
    tb->sdram_clki = !tb->sdram_clki;
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
void single_write(int val) {
    // takes a few clock cycles
    iwait(4);
    do { iclock_cycle(); } while ( !tb->rdy );
    tb->ctl = 2; // rdwr_b = 1
    tb->we = 1;
    tb->datain = val;
    iclock_cycle();
    tb->we = 0;
    tb->ctl = 0;
    tb->datain = 0;
    iwait(5);
}

/**
 *	Send a read.  Wait until a rdy comes back with the data
 **/

int single_read() {
    
    iwait(5);
    tb->ctl = 2;
    iclock_cycle();
    tb->ctl = 0;
    iclock_cycle();
    do { iclock_cycle(); } while (!tb->rdy);    
    int val = tb->dataout;
    iwait(5);
    return val;
}

#define dprintf(...) printf(__VA_ARGS__)

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


    enum  { 
        ONE=0,
        TWO=1,
        THREE=4,
        FOUR=5 } ctl_states;


// gpif state machine
    int wait=0;
    while ( !exit ) {
        dataout_s = tb->dataout;
        rdy_s = tb->rdy; 

        iclock_cycle(); // brings us to the next state

  
        switch ( state ) {
           case 0:
                tb->ctl = 2;
                if ( rdy_s ) { //tb->rdy ) {
                    state = 1;
                } else {
                    ++wait;
                    if (wait>20000) {
                        dprintf ( "Waited %d cycles.. Timeout\n", wait );
                        exit=true;
                    }
                }
                break;
            case 1:
                tb->ctl = 2|TWO;
                if ( !rdy_s || read>=count ) {
                   state = 2; 
                 //  tb->ctl = 0;
                }
                buf[read++] = dataout_s;
                break;
            case 2:
            case 3:
            case 4:
            case 5:
                tb->ctl = 0|THREE;
                if (rdy_s) {
                    state = 1;
                } else {
                    state = state+1;
                }
                break;
            case 6:
               tb->ctl = 0|FOUR;
               tb->ctl = 0;
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

//// gpif state machine
//    int wait=0;
//    while ( !exit ) {
//        dataout_s = tb->dataout;
//        rdy_s = tb->rdy; 
//
//        iclock_cycle(); // brings us to the next state
//
//  
//        switch ( state ) {
//            case 0:
//                state = 1;
//                tb->ctl=2|ONE;
//                break;
//            case 1:
//                if ( rdy_s ) { //tb->rdy ) {
//                    state = 2;
//                    tb->ctl = 2|TWO;
//                } else {
//                    ++wait;
//                    if (wait>20000) {
//                        dprintf ( "Waited %d cycles.. Timeout\n", wait );
//                        exit=true;
//                    }
//                }
//                break;
//            case 2:
//                if ( !rdy_s || read>=count ) {
//                   state = 3; 
//                   tb->ctl = 0|THREE;
//                 //  tb->ctl = 0;
//                }
//                buf[read++] = dataout_s;
//                break;
//            case 3:
//            case 4:
//            case 5:
//                if (rdy_s) {
//                    state = 2;
//                    tb->ctl = 2|TWO;
//                } else {
//                    state = state+1;
//                    tb->ctl = FOUR; // 101
//                }
//                break;
//            case 6:
//               if ( read >= count ) {
//                 exit=true; 
//               } else {
//                 state = 1;
//                 tb->ctl = 2|ONE;
//               }
//               break;
//            default:
//                assert ( NULL );
//        }
//       
//    }
     
//    // state 0
////    printf ( "STATE0\n" );
//    tb->ctl = 2; 
//
//    while (true) {
//        
//        // state 1
//        iclock_cycle();
// //       printf ( "STATE1\n" );
//        int wait_count=0;
//        while (!tb->rdy) { 
//         ++wait_count; 
////         printf ( "." );
//         iclock_cycle(); 
//         if (wait_count > 1000) {
//          printf ("Waited more than 1000 cycles for rdy.. timeout.\n" );
//          return;
//         }
//        }
//        printf ( "\n" );
//    
//        while (true) {
//         // state 2
//         do {
//          tb->ctl = 2;
//  //        printf ( "STATE2\n" );
//          iclock_cycle();
//          buf[read++] = tb->dataout;
//         } while ( tb->rdy && read < count );
//    
//    
//         // state 3
//         tb->ctl = 0;
////         printf ( "STATE3\n" );
//         iclock_cycle();
//         if (!tb->rdy) break;
//        }
//        
//    
//        // state 4
//    //    tb->ctl = 0;
//    //    printf ( "STATE4\n" );
//        iclock_cycle();
//    
//        if ( read >= count ) break;
//        tb->ctl = 2;
//    }
    
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
  single_write(val);
  tb->state= IDLE;
  iclock_cycle();


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
  val=single_read();
  tb->state = IDLE;
  iclock_cycle();
  
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
//  result = self->pDevIf->read(term, addr,(char*)data,length);

  set_addrs(term,addr);

  tb->state = RDTC;
  single_write(length/2); 

  tb->state = RDDATA;

  fifo_read(length/2,(uint16_t*)data);

  tb->state = IDLE;
  iclock_cycle();
 
  Py_END_ALLOW_THREADS

//  CHECK_DEVIF_RET(result);

  Py_RETURN_NONE;
  
}

//static PyObject *read(PyObject *self, PyObject *args) {
//  int ep_addr;
//  int reg_addr;
//  int len;
//
//  uint16_t *data=NULL;
//  npy_intp dims[1];
//  PyObject *img;
//
//  CHECK_INIT
//
//  if (!PyArg_ParseTuple(args, "iii", &ep_addr, &reg_addr, &len) ) {
//    PyErr_SetString(PyExc_Exception, "Expected arguments: ep-addr: Integer, reg_addr: Integer, len (n bytes): Integer");
//    return NULL;
//  }
//  
//  set_addrs(ep_addr,reg_addr);
//
//  tb->state = RDTC;
//  single_write(len/2); 
//
//  tb->state = RDDATA;
//// data comes two bytes at a time
//  data = (uint16_t *) malloc(len/2*sizeof(uint16_t));
//  fifo_read(len/2,data);
//  
////  for (int i=0;i<len/2;++i) {
////    printf ( "Data %d: %d\n", i, buf[i]);
////  }
//  
//  tb->state = IDLE;
//  iclock_cycle();
//  
////  char *chars = (char*)malloc(len*sizeof(char));
////  // data goes back little-endian I believe
////  for (int i=0,j=0;i<len/2;++i,j+=2) {
////    chars[j] = buf[i] & 0xff;
////    chars[j+1] = (buf[i] >> 8) & 0xff;
//////    printf ( "char %d: %d\n" , j, chars[j]);
//////    printf ( "char %d: %d\n", j+1, chars[j+1]);
////  }
//  
//  //
//  // if we make it here, the image has been captured, so let's put it into
//  // a numpy array
//  dims[0] = len/2;
////  dims[1] = cols;
//  img = PyArray_SimpleNewFromData(1, dims, NPY_UINT16, data);
//  
//  // Now setup the flags to make this array owner of the data buffer
//  // so that it will deallocate it correctly when it gets deleted.  Would
//  // do that in the creation of this object, but the documentation says that
//  // it will PyArray_NewFromDesc() function clears the NPY_OWNDATA flag.
//  PyArray_FLAGS(img) |= NPY_OWNDATA | NPY_WRITEABLE | NPY_ALIGNED;
//  
//  return img;
// 
// /* PyObject *ret = PyString_FromStringAndSize( chars, len );
//  free(buf);
//  free(chars);
//  
//  return ret; */
//}


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


/*
static PyObject *load_img(PyObject *self, PyObject *args) {
  PyObject *img;
  CHECK_INIT
  if (!PyArg_ParseTuple(args, "O", &img)) {
    PyErr_SetString(PyExc_Exception, "Argument should be a numpy array");
    return NULL;
  }
  if(!PyArray_Check(img) ||
     (PyArray_NDIM(img) > 3) ||
     (PyArray_NDIM(img)==3 && PyArray_DIM(img, 2) > 1) ||
     (PyArray_NDIM(img)<2) ||
     (PyArray_DIM(img, 0) != ROWS) || (PyArray_DIM(img, 1) != COLS)) {
    PyErr_SetString(PyExc_Exception, "Array is not the correct size");
    return NULL;
  }

  img = (PyObject *) PyArray_GETCONTIGUOUS((PyArrayObject *) img); // this creates a new refernce that we need to decrement when done.  Furthermore it ensures the data is contiguous, which is necessary to memcpy it into the imager.

  if(PyArray_TYPE(img) == NPY_UINT) {
    tb->v->top->top_ana->m_top_ana->load_img<npy_uint>((npy_uint*) PyArray_DATA(img));
  } else if(PyArray_TYPE(img) == NPY_USHORT) {
    tb->v->top->top_ana->m_top_ana->load_img<npy_ushort>((npy_ushort*) PyArray_DATA(img));
  } else {
    PyErr_SetString(PyExc_Exception, "Your array type is not supported.  Use a uint32 or uint16.");
    Py_DECREF(img);
    return NULL;
  }
  Py_DECREF(img); // delete the reference I create with the GETCONTIGUOUS command
  Py_RETURN_NONE;
}
*/
/*
static PyObject *shape(PyObject *self, PyObject *args) {
  CHECK_INIT
  return Py_BuildValue("ii", tb->v->top->top_ana->m_top_ana->rows(), tb->v->top->top_ana->m_top_ana->cols());
} */
/*
static PyObject *capture_frame(PyObject *self, PyObject *args, PyObject *keywds) {
  int rows, cols, pos, max_pos, col_count;
  uint16_t *data=NULL;
  int timeout = -1;
  npy_intp dims[2];
  PyObject *img;
  PyObject *callback = NULL, *callback_result, *callback_args;
  static char *kwlist[] = { "timeout", "callback",NULL };

  CHECK_INIT

  if(!PyArg_ParseTupleAndKeywords(args, keywds, "|iO", kwlist, &timeout, &callback)) {
    return NULL;
  }

  if(callback && !PyCallable_Check(callback)) {
    PyErr_SetString(PyExc_Exception, "callback function is not callable.");
  }

  if(tb->clk == 0) advance(); // sync to clock rising edge

  // wait until fv goes high
  while((timeout == -1 || timeout > 0) && (tb->fv == 0)) {
    wait(2); // advance 1 whole clock cycle
  }

  // check if fv is high and raise a timeout exception if it hasn't
  if(!tb->fv) {
    PyErr_SetString(PyExc_Exception, "Timed out waiting for frame valid signal fv to go high");
    return NULL;
  }

  // initially set rows and cols to max.  later we will update these parameters
  // after collecting the actual image based on the fv and lv signals.
  rows = tb->v->top->top_ana->m_top_ana->rows();
  cols = tb->v->top->top_ana->m_top_ana->cols();
  max_pos = rows * cols;

  // allocate the a buffer that can hold the max image.
  data = (uint16_t *) malloc(rows*cols*sizeof(uint16_t));
  if(!data) { 
    PyErr_SetString(PyExc_Exception,"Error allocating memory to store image.");
    goto error1; 
  }
    
  // now collect the image and measure the rows and cols
  cols = -1;
  rows = 0;
  pos = 0;
  while(tb->fv) {
    while(!tb->lv && tb->fv) { wait(2); } // wait for line valid to go high

    if(!tb->fv) { break; } // done with the frame

    // if we made it here, lv is high, so let's collect this row
    col_count = 0;
    while(tb->lv && tb->fv) {
      if(pos >= max_pos) {
	PyErr_SetString(PyExc_Exception,"Error: Image collected image is larger than phyiscal image.");
	goto error1;
      }
      col_count += 1;
      data[pos++] = ((uint16_t) tb->data_out) << (16-DATA_WIDTH); // record the data and left justify it.
      wait(2); // go to the next clock
    }
    rows++; // record this row

    // check if the number of cols in this row is consistent with the others
    if(cols == -1) {
      cols = col_count;
    } else {
      if(col_count != cols) {
	PyErr_SetString(PyExc_Exception,"Error occurred collecting image.  The number of columns per row is not consistent");
	goto error1;
      }
    }

    // call the row received callback
    if(callback) {
      callback_args = Py_BuildValue("(i)", rows);
      callback_result = PyEval_CallObject(callback, callback_args);
      Py_DECREF(callback_args);
      if(!callback_result) {  // an exception occurred in the callback
	goto error1;
      }
      Py_DECREF(callback_result);
    }
  }

  // reduce the memory allocation now if necessary
  data = (uint16_t *) realloc(data, rows*cols*sizeof(uint16_t));

  // if we make it here, the image has been captured, so let's put it into
  // a numpy array
  dims[0] = rows;
  dims[1] = cols;
  img = PyArray_SimpleNewFromData(2, dims, NPY_UINT16, data);
  
  // Now setup the flags to make this array owner of the data buffer
  // so that it will deallocate it correctly when it gets deleted.  Would
  // do that in the creation of this object, but the documentation says that
  // it will PyArray_NewFromDesc() function clears the NPY_OWNDATA flag.
  PyArray_FLAGS(img) |= NPY_OWNDATA | NPY_WRITEABLE | NPY_ALIGNED;
  
  return img;

 error1:
  if(data) { free(data); }
  return NULL;

}
*/
/*
static PyObject *set_col_offsets(PyObject *self, PyObject *args) {
  int cols;
  PyObject *offsets;

  CHECK_INIT

  if(!PyArg_ParseTuple(args, "O", &offsets)) { 
    return NULL;
  }

  cols = tb->v->top->top_ana->m_top_ana->cols();
  if(!PyArray_Check(offsets) || PyArray_NDIM(offsets) != 1 ||
     PyArray_DIM(offsets, 0) != cols) {
    PyErr_SetString(PyExc_Exception, "Argument not a numpy array or not the right size");
    return NULL;
  }

  offsets = (PyObject *) PyArray_GETCONTIGUOUS((PyArrayObject *) offsets); // this creates a new refernce that we need to decrement when done.  Furthermore it ensures the data is contiguous, which is necessary to memcpy it into the imager.

  if(PyArray_TYPE(offsets) == NPY_UINT) {
    tb->v->top->top_ana->m_top_ana->set_col_offsets<npy_uint>((npy_uint*) PyArray_DATA(offsets));
  } else if(PyArray_TYPE(offsets) == NPY_USHORT) {
    tb->v->top->top_ana->m_top_ana->set_col_offsets<npy_ushort>((npy_ushort*) PyArray_DATA(offsets));
  } else {
    PyErr_SetString(PyExc_Exception, "Your array type is not supported.  Use a uint32 or uint16.");
    Py_DECREF(offsets);
    return NULL;
  }
  Py_DECREF(offsets); // delete the reference I create with the GETCONTIGUOUS command
  Py_RETURN_NONE;
}
*/

//typedef struct t_SignalTrans {
//  char *name;
//  void *signal;
//}
//
//static SignalTrans sig_trans[] = {
//  {"clk", tb->clk,  },
//  {"reset_n", tb->reset_n },
//  {"i2c_master_header", tb->i2c_master_header },
//  {"i2c_master_addr", tb->i2c_master_addr },
//  {"i2c_master_datai", tb->i2c_master_datai },
//  {"i2c_master_datao", tb->i2c_master_datao },
//  {"i2c_master_we", tb->i2c_master_we },
//  {"i2c_master_re", tb->i2c_master_re },
//  {"i2c_master_status", tb->i2c_master_status },
//  {"i2c_master_clk_divider", tb->i2c_master_clk_divider },
//  {"fv", tb->fv },
//  {"lv", tb->lv },
//  {"data_out", tb->data_out },
//  {NULL, NULL}  /* Sentinel */
//};


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
