#ifndef _FX3_VERILATOR_H
#define _FX3_VERILATOR_H

#include "verilated.h"
#include "nitro.h"
#include <limits.h>
   
using namespace Nitro;
enum {
  FX3_READ_CMD=1,
  FX3_WRITE_CMD=2
};

typedef struct {
  uint16_t cmd;
  uint16_t buffer_length;
  uint16_t term_addr;
  uint16_t reserved;
  uint32_t reg_addr;
  uint32_t transfer_length;
} slfifo_cmd_t;

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

class FX3Device : public Device {
private:
  void send_cmd(int cmd, int term, int reg, int len) {

    *hics_b  = 1;
    advance_clk(50);
    *hics_b  = 0;
    advance_clk(20);
    
    slfifo_cmd_t *slfifo = (slfifo_cmd_t *) cbuf;
    slfifo->cmd             = 0xC300 | (cmd & 0xFF);
    slfifo->buffer_length   = 256*4;
    slfifo->term_addr       = term;
    slfifo->reserved        = 0;
    slfifo->reg_addr        = reg;
    slfifo->transfer_length = len;
    *cmd_ptr = 0;
    *rptr    = 0;
    *rdone   = 0;
    advance_clk(20);
  }

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
  DataType _get(uint32 terminal_addr, uint32 reg_addr, uint32 timeout ) {
    uint16 val;
    uint32_t timeout_time = get_timeout_time(timeout);
    if(reg_addr == 4 and terminal_addr == 6) {// hack to pass firmware version
       return DataType( static_cast<uint32>(512));
    }                                         
    _read(terminal_addr, reg_addr, (uint8*) (&val), 2, timeout);
    return DataType( static_cast<uint32>((uint32) val));
  }

  void _read( uint32 terminal_addr, uint32 reg_addr, uint8* data, size_t length, uint32 timeout ) {
    uint32_t timeout_time = get_timeout_time(timeout);
    send_cmd(FX3_READ_CMD, terminal_addr, reg_addr, length);
    advance_clk(1);

    size_t rx_count = 0;
    uint32 *rx_data = (uint32 *) malloc(length + 8);

    while(rx_count < length/4 + 2) {//include ack buffer
      if(*rdone || (*full_b==0)) {
        advance_clk(100);
        for(int pos=0; pos<*rptr; pos++) {
          rx_data[rx_count] = rbuf[pos];
	  printf("RX 0x%04x: 0x%08x\n", rx_count, rx_data[rx_count]);
          rx_count++;
        }
        *rdone = 0;
        *rptr  = 0;
        advance_clk(100);
      }
      advance_clk(1);
      if(main_time >= timeout_time) {
        free(rx_data);                         
        throw Exception(USB_COMM, "Timed out");
      }
    }
    // copy rx_data into data buffer and separate out the ack
    uint16 checksum=0;
    for(int pos=0; pos<length/4; pos++) {
       ((uint32*)data)[pos] = rx_data[pos];
       checksum += rx_data[pos];       
    }

    ack_pkt_t *ack_pkt = (ack_pkt_t *) (rx_data + length/4);
    printf("ACK PKT\n");
    printf(" id       = 0x%04x\n", ack_pkt->id);
    printf(" checksum = 0x%04x\n", ack_pkt->checksum);
    printf(" status   = 0x%04x\n", ack_pkt->status);


    char msg[256];
    if(ack_pkt->id != 0xA50F) {
      free(rx_data);                           
      throw Exception(USB_COMM, "Unexpected ack code returns");
    }
    // check checksum
    checksum = checksum & 0xFFFF;
    if(ack_pkt->checksum != checksum) {
      free(rx_data);                           
      sprintf(msg, "Checksum mismatch: 0x%04x/0x%04x", ack_pkt->checksum, checksum);
      throw Exception(USB_COMM, msg);
    }
    // check status word
    if(ack_pkt->status != 0) {
      sprintf(msg, "Non-zero ACK status 0x%x (%d) returned.", ack_pkt->status, ack_pkt->status);
      free(rx_data);
      throw Exception(USB_COMM, msg, ack_pkt->status);
    }

    advance_clk(1);
    free(rx_data);                             
  }

  void _set(uint32 terminal_addr, uint32 reg_addr, const DataType& type, uint32 timeout ) {
    uint16 data = (uint16) static_cast<uint32>(type);
    _write(terminal_addr, reg_addr, (uint8*) (&data), 2, timeout);
  }

  void _write( uint32 terminal_addr, uint32 reg_addr, const uint8* data, size_t length, uint32 timeout ) {
    uint32_t timeout_time = get_timeout_time(timeout);
    unsigned int checksum = 0;
    send_cmd(FX3_WRITE_CMD, terminal_addr, reg_addr, length);
    advance_clk(1);

    // write the data
    size_t tx_count = 0;
    while(tx_count < length) {
      if(*wptr >= *wend) {
        advance_clk(100);
        // fill the tx buffer
        int i;
        for(i=0; (i<256) && (tx_count<length); i++) {
          wbuf[i] = data[tx_count] + (data[tx_count + 1] << 8) + (data[tx_count + 2] << 16) + (data[tx_count + 3] << 24);
          checksum += wbuf[i];                                       
          //printf("wbuf[%d]=0x%x txcount=%d\n", i, wbuf[i], tx_count);
          tx_count += 4;
        }
        *wptr = 0;
        *wend = i;
      }
      advance_clk(1);
      if(main_time >= timeout_time) {
        throw Exception(USB_COMM, "Timed out waiting transfer");
      }
    }

    // wait for ack
    while(*rptr < 2) {
      advance_clk(1);
      if(main_time >= timeout_time) {
        throw Exception(USB_COMM, "Timed out waiting for ack");
      }
    }
    // check ack
    *rptr = 0;

    ack_pkt_t *ack_pkt = (ack_pkt_t *) rbuf;
    printf("ACK PKT\n");
    printf(" id       = 0x%04x\n", ack_pkt->id);
    printf(" checksum = 0x%04x\n", ack_pkt->checksum);
    printf(" status   = 0x%04x\n", ack_pkt->status);

    char msg[256];
    if(ack_pkt->id != 0xA50F) {
      throw Exception(USB_COMM, "Unexpected ack code return: 0x%x", ack_pkt->id);
    }
    // check checksum
    checksum = checksum & 0xFFFF;
    if(ack_pkt->checksum != checksum) {
      sprintf(msg, "Checksum mismatch: 0x%04x/0x%04x", ack_pkt->checksum, checksum);
      throw Exception(USB_COMM, msg);
    }
    // check status word
    if(ack_pkt->status != 0) {
      sprintf(msg, "Non-zero ACK status 0x%x (%d) returned.", ack_pkt->status, ack_pkt->status);
      throw Exception(USB_COMM, msg, ack_pkt->status);
    }

    advance_clk(3);

  }


  void _close() {}
  
 public:
  
  FX3Device() {}
  ~FX3Device() throw() {}
  
  IData *wbuf, *rbuf, *cbuf;
  SData *wptr, *rptr, *wend;
  CData *rdone, *hics_b, *full_b, *empty_b, *cmd_ptr;
  

};
#endif
