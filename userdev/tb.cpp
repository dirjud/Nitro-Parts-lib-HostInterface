#include <nitro/types.h>
#include <nitro/error.h>

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



extern "C" void* ud_init(const char* args[]) {
  const char *filename=args[0];

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
  return NULL;
}

extern "C" void ud_set ( uint32 terminal_addr, uint32 reg_addr, uint32 value, uint32 timeout, void* ud ) {
  
  set_addrs(terminal_addr,reg_addr);
  tb->state = SETRVAL;
  int ret=single_write(value);
  tb->state= IDLE;
  iclock_cycle();

  
  if (ret<0) {
    throw Nitro::Exception ( "Write didn't work" );
  }

}


extern "C" uint32 ud_get ( uint32 terminal_addr, uint32 reg_addr, uint32 timeout, void* ud ) {
  int val;
  
  set_addrs(terminal_addr,reg_addr);
  tb->state = GETRVAL;
  int ret=single_read(&val);
  tb->state = IDLE;
  iclock_cycle();

  if (ret < 0) {
    throw Nitro::Exception ( "Get Didn't work" );
  }

  
  return val;
}


extern "C" void ud_read( uint32 terminal_addr, uint32 reg_addr, uint8* data, size_t length, uint32 timeout, void* ud ) {


  set_addrs(terminal_addr,reg_addr);

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
 
}


extern "C" void ud_write( uint32 terminal_addr, uint32 reg_addr, const uint8* data, size_t length, uint32 timeout, void* ud ) { 
  // no ep's implemented right now.
  //
  iwait(50);

}

extern "C" void ud_close(void*){

  tb->final();
  delete tb;
  if(trace) {
    tfp->close();
    delete tfp;
  }
  tb = NULL;
  tfp = NULL;
}


