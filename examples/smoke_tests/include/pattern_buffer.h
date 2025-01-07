#include <stdint.h>
#include <stddef.h>


struct pattern_buffer {
    uint8_t* buffer;
    uint8_t  len;
    int16_t  head;
    int16_t  tail;
    uint8_t* pattern;
    uint8_t  payload;   
    uint16_t data_count;   // keeps track of the number of accesses to the pattern buffer 
};                         // can be used to improve the runtime of pattern_buffer_check_pattern

// Buffer init
void pattern_buffer_init(struct pattern_buffer *pb, uint8_t *buffer, uint8_t len, uint8_t* pattern) {
    pb->buffer = buffer;
    pb->len = len;
    pb->head = 0;
    pb->tail = len-1;
    pb->pattern = pattern;
    pb->payload = 0;
    pb->data_count = 0;
}


void pattern_buffer_push(struct pattern_buffer *pb, uint8_t data){
    if(pb->buffer != NULL){
      pb->payload = (pb->buffer)[pb->tail];
      pb->buffer[pb->tail] = data;
      pb->tail = (pb->tail + 1) % (pb->len);
      pb->head = (pb->head + 1) % (pb->len);

      pb->data_count++;
    }
}


void pattern_buffer_reset_buffer(struct pattern_buffer *pb){
  for(uint8_t i=0; i<pb->len; i++){
    pb->buffer[i] = 0;
  }
  pb->payload = 0;
  pb->data_count = 0;

  pb->head = 0;
  pb->tail = pb->len-1;
}


bool pattern_buffer_check_pattern(struct pattern_buffer *pb){
  for(uint8_t i=0; i<pb->len; i++){
    if(pb->buffer[(pb->tail + i) % (pb->len)] != (pb->pattern[pb->len - i - 1]))
      return false;
  }
  return true;
}
