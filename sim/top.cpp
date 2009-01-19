#include <cstdio>

#include <verilated.h>
#include <SpTraceVcdC.h>
#include "Vtop.h"


typedef enum {
    IDLE=0,
    SETEP=1,
    SETREG=2,
    SETRVAL=  3,
    RDDATA = 4,
    RESETRVAL = 5,
    WRDATA = 6
} HI_STATE;


Vtop *top;
SpTraceVcdCFile *tfp;

unsigned int main_time=0;

double sc_time_stamp() {
 return main_time;
}

void do_clock() {
    top->if_clock = !top->if_clock;
    top->eval();
    tfp->dump(main_time);
    ++main_time;
}

/**
 * Advance to next clock rise
 **/
void clock_rise(int cycles=1) {
    for (int i=0;i<cycles;++i) {
        do_clock();
        do_clock();
    }
    if (top->if_clock) do_clock();
}

void set_state(HI_STATE state) {
    top->state = state;
    clock_rise(5); // takes a while to set the state on the firmware side
}

/**
 *  write a value to the hi
 **/
void do_write(int val) {
    // rdwr for one cycle
    clock_rise();
    top->ctl = 2; // 010
    top->we = 1;
    top->datain = val;
    clock_rise();
    top->ctl = 0;
    top->we = 0;
    //clock_rise();
}

void do_read(int count=1,int buf[]=NULL) {
    
    // rdwr for one cycle
    int read=0,rdy=0,attempt=0;
    bool read_state[2]={false,false};    
    while ( read < count && attempt++<100) {
        clock_rise();
        //printf ( "%s ready\n", top->rdy ? "" : "Not");
        if (read_state[0]) {
         if (buf) buf[read] = top->dataout;
         printf ( "Read %d\n", buf[read] );
         ++read;
        }        
        top->ctl = rdy < count && top->rdy ? 2 : 0;
        read_state[0] = read_state[1];
        read_state[1] = top->ctl == 2;
        if (top->ctl == 2) ++rdy;
    }
    
}

void do_di_set(int ep,int reg,int val) {
   set_state(SETEP);
   do_write(ep);
   set_state(SETREG);
   do_write(reg);
   set_state(SETRVAL);
   do_write(val);
   
}

void do_di_get(int ep, int reg, int count=1,int buf[]=NULL) {
    
    set_state(SETEP);
    // set read high for one cycle
    do_write(ep);
    set_state(SETREG);
    do_write(reg);
    set_state(RDDATA);
    do_read(count,buf);
    if (buf) {
        for (int i=0;i<count;++i)
           printf ( "ep: %d, reg: %d, val: %d\n", ep,reg,buf[i] );
    }
}




int main(int argc, char* argv[]) {


 top = new Vtop;
 Verilated::traceEverOn(true);
 tfp = new SpTraceVcdCFile();
 top->trace(tfp,99);
 tfp->open("trace.vcd");

 while ( main_time < 101 ) do_clock();
 
 int buf[10];
 do_di_set(0,1,10); // set the led to 10
 do_di_get(0,0,1,buf);
 do_di_get(0,1,1,buf);
 do_di_get(0,2,10,buf);
 //do_di_get(0,2,10,buf);
 
 
 clock_rise(10);

 tfp->close();
 top->final();
 

 return 0;
}
