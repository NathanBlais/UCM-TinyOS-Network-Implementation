#ifndef __SOCKET_H__
#define __SOCKET_H__

enum{
    MAX_NUM_OF_SOCKETS = 10,
    ROOT_SOCKET_ADDR = 255,
    ROOT_SOCKET_PORT = 255,
    SOCKET_BUFFER_SIZE = 128,
};

enum socket_state{
    CLOSED       = 0,
    LISTEN       = 1,
    SYN_SENT     = 2,
    SYN_RCVD     = 3,
    ESTABLISHED  = 4,
    CLOSE_WAIT   = 5,
    LAST_ACK     = 6,
    FIN_WAIT_1   = 7,
    FIN_WAIT_2   = 8,
    TIME_WAIT    = 9
};

typedef nx_uint8_t nx_socket_port_t;
typedef uint8_t socket_port_t;

// socket_addr_t is a simplified version of an IP connection.
typedef nx_struct socket_addr_t{
    nx_socket_port_t port;
    nx_uint16_t addr;
}socket_addr_t;


// File descripter id. Each id is associated with a socket_store_t
typedef uint8_t socket_t;

enum {
  /* how many timer tics to stay in TIME_WAIT */
  TIMEWAIT_LEN = 1,
  //2MSL = 4,
  /* how many un-acked retransmissions before we give up the connection */
  GIVEUP = 6,
};


typedef struct socket_store_t{ //(TCB) - Transmission Control Block
    uint8_t flag;

    /* current connection state */
    enum socket_state state;

    /* local and remote endpoints */
    socket_port_t src;
    socket_addr_t dest;

/*
    Send Sequence Space

                   1         2          3          4
              ----------|----------|----------|----------
                     SND.UNA    SND.NXT    SND.UNA
                                          +SND.WND

        1 - old sequence numbers which have been acknowledged
        2 - sequence numbers of unacknowledged data
        3 - sequence numbers allowed for new data transmission
        4 - future sequence numbers which are not yet allowed
*/

    // This is the sender portion.
    uint8_t sendBuff[SOCKET_BUFFER_SIZE];
    uint8_t lastWritten;    //packet sequence number allowed for new data transmission
    uint8_t lastSent;       // SND.UNA - last sent data that is not acknowledged yet
    uint8_t lastAck;        //last ack sent

/*
    Receive Sequence Space

                       1          2          3
                   ----------|----------|----------
                          RCV.NXT    RCV.NXT
                                    +RCV.WND

        1 - old sequence numbers which have been acknowledged
        2 - sequence numbers allowed for new reception
        3 - future sequence numbers which are not yet allowed
*/
    // This is the receiver portion
    uint8_t rcvdBuff[SOCKET_BUFFER_SIZE];
    uint8_t lastRead; //last packet put into the buffer
    uint8_t lastRcvd; //largest packet recived
    uint8_t nextExpected; //next packet expected

    uint16_t RTT;
    uint8_t effectiveWindow;

    /* retransmission counter */
    uint16_t reTransCnt;

    pack LastSentIPpackage;

}socket_store_t;

#endif