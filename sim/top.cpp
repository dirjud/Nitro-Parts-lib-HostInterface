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
    GETRVAL = 6,
    RDTC   = 7,
    WRDATA = 8
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
    do { clock_rise(); } while ( !top->rdy );
    top->ctl = 2; // 010
    top->we = 1;
    top->datain = val;
    clock_rise();
    top->ctl = 0;
    top->we = 0;
    //clock_rise();
}

void do_read(int count=1,int buf[]=NULL) {
    

    top->ctl = 2; // in read until done
    int read = 0;
    int rdy_s=0;
    while ( read < count ) {
        rdy_s = top->rdy;
        clock_rise();
        if ( rdy_s ) {
            buf[read++] = top->dataout;
        }
    }

    
}

int do_get() {
    top->ctl=2; // read
    clock_rise();
    top->ctl=0;
    do { clock_rise(); } while ( !top->rdy );
    return top->dataout;
    
}

void do_di_set(int ep,int reg,int val) {
   set_state(SETEP);
   do_write(ep);
   set_state(SETREG);
   do_write(reg);
   set_state(SETRVAL);
   do_write(val);
   
}


int do_di_get(int ep,int reg ) {
    set_state(SETEP);
    do_write(ep);
    set_state(SETREG);
    do_write(reg);
    set_state(GETRVAL);
    return do_get();
}

void do_di_read(int ep, int reg, int count=1,int buf[]=NULL) {
    
    set_state(SETEP);
    // set read high for one cycle
    do_write(ep);
    set_state(SETREG);
    do_write(reg);
    set_state(RDTC);
    do_write(count);
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
 printf ( "led value: %d\n" , do_di_get(0,1) );
 printf ( "button 1 val: %d\n" , do_di_get(0,0) );
 for (int i=0;i<2;++i) {
    do_di_set(0,2,0xab);  // write to the slow writer guy
    printf ( "Set the slow writer\n" );
 }
  
 printf ( "Get Counter: %d\n", do_di_get(0,4));
 // counter
 do_di_read(0,3,10,buf);
 
 for (int i=0;i<6;++i)
    printf ( "Get Counter: %d\n", do_di_get(0,4));
    
 do_di_read(0,3,8,buf);
 
 for (int i=0;i<3;++i)
    printf ( "Get slow writer: %d\n", do_di_get(0,2));
 
 clock_rise(50);

 tfp->close();
 top->final();
 

 return 0;
}
