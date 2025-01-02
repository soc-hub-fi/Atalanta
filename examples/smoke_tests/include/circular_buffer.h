#include <stdint.h>
#include <stddef.h>


struct circular_buffer {
    uint8_t* buffer;
    uint8_t size;
    uint8_t head;
    uint8_t tail;
};

// Buffer init
void circular_buffer_init(struct circular_buffer *cb, uint8_t *buffer, uint8_t size) {
    cb->buffer = buffer;
    cb->size = size;
    cb->head = 0;
    cb->tail = 0;
}
void circular_buffer_push(struct circular_buffer *cb, uint8_t data){
    if(cb->buffer!=NULL){
        cb->buffer[cb->head] = data;
        cb->head++;
        
        if(cb->head == cb->size){
            cb->head = 0;
        }
    }
}

uint8_t circular_buffer_pop(struct circular_buffer *cb){
    const uint8_t data = cb->buffer[cb->tail];
    cb->tail++;

    if(cb->tail == cb->size){
        cb->tail = 0;
    }

    return data; 
}

uint8_t circular_buffer_show(struct circular_buffer *cb){
    return cb->buffer[cb->tail];
}

bool circular_buffer_empty(struct circular_buffer *cb){

    return cb->tail == cb->head;

}

bool circular_buffer_full(struct circular_buffer *cb){

    uint8_t next_head = cb->head + 1; 

    if(next_head == cb->size){
        next_head= 0;
    } 

    return next_head == cb->tail; // will return true if: 
                                    //the next head is equal to buffer size && tail is still 0 (i.e did not pop anything) 
}

uint8_t circular_buffer_size(struct circular_buffer *cb){
    return (cb->head - cb->tail);
};
