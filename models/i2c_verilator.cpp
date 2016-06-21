#ifndef _I2C_VERILATOR_H_
#define _I2C_VERILATOR_H_

#include "verilated.h"
#include "nitro.h"
#include <limits.h>
using namespace Nitro;

typedef struct {
  uint16_t id;
  uint16_t checksum;
  uint16_t status;
  uint16_t reserved;
}
#ifdef __GNUC__
 __attribute__((__packed__))
#endif
ack_pkt_t;

extern void advance_clk(unsigned int cycles);
extern unsigned int main_time;

class I2CDevice : public Device {
private:
  uint32_t get_timeout_time(uint32_t timeout) {
    uint32_t timeout_time;
    if(timeout == 0) { 
      timeout_time = UINT_MAX;
    } else {
      timeout_time = main_time + (timeout * 1000000);
    }
    return timeout_time;
  }
  
protected:
  
  void _read( uint32 terminal_addr, uint32 reg_addr0, uint8* data, size_t length, uint32 timeout ) {
    uint32_t timeout_time = get_timeout_time(timeout);

    // TODO need to associate terminals_defs.h 
    // to pick out FX3/UXN1330 addresses to filter to not send
    // them to the fpga sim.
    // even better somehow sim those terminals.
    // extend this model?
    if (terminal_addr == 0x100 // fx3
     || terminal_addr == 5 // dummy fx3
     || terminal_addr == 80) // fx3 prom 
    return; // pretend it worked

    size_t rx_count = 0;
    *term_addr = terminal_addr;
    *reg_addr  = reg_addr0;
    advance_clk(1);

    while(rx_count < length) {
      *i2c_re = 1;
      advance_clk(1);
      *i2c_re = 0;
      advance_clk(10);
      while(*i2c_busy) {
	advance_clk(1);
	if(main_time >= timeout_time) {
	  throw Exception(USB_COMM, "Timed out waiting transfer");
	}
      }
      *reg_addr  = *reg_addr + 1;
      *((uint32*) (data + rx_count)) = *reg_datao;
      //printf("0x%x %d\n", *reg_datao, length);
      if(*i2c_status) {
	throw Exception(USB_COMM, "Unexpected ack code return: 0x%x", *i2c_status);
      }
      rx_count += 4;
    }
  }

  void _write( uint32 terminal_addr, uint32 reg_addr0, const uint8* data, size_t length, uint32 timeout ) {
    uint32_t timeout_time = get_timeout_time(timeout);
    unsigned int checksum = 0;

    // see comment in _read
    if (terminal_addr == 0x100 // fx3
     || terminal_addr == 5 // dummy fx3
     || terminal_addr == 80) // fx3 prom 
    return; // pretend it worked

    // write the data
    size_t tx_count = 0;
    *write_mode = 1;
    *term_addr = terminal_addr;
    *reg_addr  = reg_addr0;
    advance_clk(1);

    while(tx_count < length) {
      *reg_datai = data[tx_count] + (data[tx_count + 1] << 8) + (data[tx_count + 2] << 16) + (data[tx_count + 3] << 24);
      checksum += *reg_datao;
      //printf("wbuf[%d]=0x%x txcount=%d\n", i, wbuf[i], tx_count);
      tx_count += 4;
      *i2c_we = 1;
      advance_clk(1);
      *i2c_we = 0;
      advance_clk(10);
      while(*i2c_busy) {
	advance_clk(1);
	if(main_time >= timeout_time) {
	  *write_mode = 0;
	  advance_clk(10);
	  throw Exception(USB_COMM, "Timed out waiting transfer");
	}
      }
      if(*i2c_status) {
	*write_mode = 0;
	advance_clk(30);
	throw Exception(USB_COMM, "Unexpected ack code return: 0x%x", *i2c_status);
      }
      *reg_addr  = *reg_addr + 1;
      advance_clk(1);
    }
    *write_mode = 0;

    advance_clk(30);
  }


  void _close() {}
  
 public:
  
  I2CDevice() {}
  ~I2CDevice() throw() {}
  
  CData *term_addr, *i2c_status;
  IData *reg_datai, *reg_datao;
  SData *reg_addr;
  CData *i2c_re, *i2c_we, *write_mode, *i2c_busy;
  

};
#endif
