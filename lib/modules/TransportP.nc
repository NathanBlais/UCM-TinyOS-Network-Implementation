//      Author:Nathan Blais
//Date Created:2020-03-21

#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/am_types.h"
#include "../../includes/command.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/socket.h"
#include "Timer.h"

module TransportP{
  provides interface Transport;

  //Uses the SimpleSend interface to transport data recieved packet
  uses interface SimpleSend as Sender;
  //Uses the Receive interface to receive packets 
//  uses interface Receive as Receiver;
//  uses interface AMPacket;
  
  //Uses the (DVR) interface to know where to forward packets.
  uses interface DistanceVectorRouting;

  uses interface Hashmap<socket_store_t> as Connections; // hash table: list of connections

 }

 implementation{

    // Globals

    const socket_t NULLSocket = 0;


    // Prototypes



   /**
    * Get a socket if there is one available.
    * @Side Client/Server
    * @return
    *    socket_t - return a socket file descriptor which is a number
    *    associated with a socket. If you are unable to allocated
    *    a socket then return a NULL socket_t.
    */
  command socket_t Transport.socket(){
    uint8_t i;
    dbg(TRANSPORT_CHANNEL,"Transport.socket() Called\n");
    if(call Connections.contains(0)) { //if there is room
      for(i=1; i-1 <= call Connections.size(); i++){
        if(!(call Connections.contains(i)))
          return (socket_t) i;
      }
    }
    dbg(TRANSPORT_CHANNEL,"Failed: No sockets are available\n");
    return NULLSocket;
  }

   /**
    * Bind a socket with an address.
    * @param
    *    socket_t fd: file descriptor that is associated with the socket
    *       you are binding.
    * @param
    *    socket_addr_t *addr: the source port and source address that
    *       you are biding to the socket, fd.
    * @Side Client/Server
    * @return error_t - SUCCESS if you were able to bind this socket, FAIL
    *       if you were unable to bind.
    */
  command error_t Transport.bind(socket_t fd, socket_addr_t *addr){
    socket_store_t TCB;    //Transmission Control Block
    int i = 0;

    dbg(TRANSPORT_CHANNEL,"Transport.bind() Called\n");
    TCB.src = fd;
    TCB.dest = *addr;
    TCB.state = CLOSED;

    // This is the sender portion.
    for (i = 0; i < SOCKET_BUFFER_SIZE; i++){ //I don't know if I need to fill this
			TCB.sendBuff[i] = 0;
		}
    TCB.lastWritten = 0;
    TCB.lastAck = 0;
    TCB.lastSent = 0;

    // This is the receiver portion
    for (i = 0; i < SOCKET_BUFFER_SIZE; i++){ //I don't know how this should be used or mannaged
      TCB.rcvdBuff[i] = 0;
		}
    TCB.lastRead = 0;
    TCB.lastRcvd = 0;
    TCB.nextExpected = 1;

    TCB.RTT = 5000;  //NOTE:We Need to replace this value
    TCB.effectiveWindow = 10;  //NOTE:We Need to replace this value

    call Connections.insert(fd, TCB);
    if(call Connections.contains(fd)){
      dbg(TRANSPORT_CHANNEL,"Socket:%d bound to Node:%d Port:%d\n", fd, addr->addr, addr->port);
      return SUCCESS;
    }
    else {
      dbg(TRANSPORT_CHANNEL,"Socket:%d bound to Node:%d Port:%d has FAILED\n", fd, addr->addr, addr->port);
      return FAIL;
    }
   }

   /**
    * Checks to see if there are socket connections to connect to and
    * if there is one, connect to it.
    * @param
    *    socket_t fd: file descriptor that is associated with the socket
    *       that is attempting an accept. remember, only do on listen. 
    * @side Server
    * @return socket_t - returns a new socket if the connection is
    *    accepted. this socket is a copy of the server socket but with
    *    a destination associated with the destination address and port.
    *    if not return a null socket.
    */
   //command socket_t Transport.accept(socket_t fd);

   /**
    * Write to the socket from a buffer. This data will eventually be
    * transmitted through your TCP implimentation.
    * @param
    *    socket_t fd: file descriptor that is associated with the socket
    *       that is attempting a write.
    * @param
    *    uint8_t *buff: the buffer data that you are going to wrte from.
    * @param
    *    uint16_t bufflen: The amount of data that you are trying to
    *       submit.
    * @Side For your project, only client side. This could be both though.
    * @return uint16_t - return the amount of data you are able to write
    *    from the pass buffer. This may be shorter then bufflen
    */
   //command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen);

   /**
    * This will pass the packet so you can handle it internally. 
    * @param
    *    pack *package: the TCP packet that you are handling.
    * @Side Client/Server 
    * @return uint16_t - return SUCCESS if you are able to handle this
    *    packet or FAIL if there are errors.
    */
   command error_t Transport.receive(pack* package){
      pack* myMsg=(pack*) package;
      tcpHeader* mySegment = (tcpHeader*) myMsg->payload;
      socket_store_t * curConection = call Connections



     switch (mySegment->state) {
    
     case TCP_LAST_ACK:
   }

   /**
    * Read from the socket and write this data to the buffer. This data
    * is obtained from your TCP implimentation.
    * @param
    *    socket_t fd: file descriptor that is associated with the socket
    *       that is attempting a read.
    * @param
    *    uint8_t *buff: the buffer that is being written.
    * @param
    *    uint16_t bufflen: the amount of data that can be written to the
    *       buffer.
    * @Side For your project, only server side. This could be both though.
    * @return uint16_t - return the amount of data you are able to read
    *    from the pass buffer. This may be shorter then bufflen
    */
   //command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen);

   /**
    * Attempts a connection to an address.
    * @param
    *    socket_t fd: file descriptor that is associated with the socket
    *       that you are attempting a connection with. 
    * @param 
    *    socket_addr_t *addr: the destination address and port where
    *       you will atempt a connection.
    * @side Client
    * @return socket_t - returns SUCCESS if you are able to attempt
    *    a connection with the fd passed, else return FAIL.
    */
   //command error_t Transport.connect(socket_t fd, socket_addr_t * addr);

   /**
    * Closes the socket.
    * @param
    *    socket_t fd: file descriptor that is associated with the socket
    *       that you are closing. 
    * @side Client/Server
    * @return socket_t - returns SUCCESS if you are able to attempt
    *    a closure with the fd passed, else return FAIL.
    */
   //command error_t Transport.close(socket_t fd);

   /**
    * A hard close, which is not graceful. This portion is optional.
    * @param
    *    socket_t fd: file descriptor that is associated with the socket
    *       that you are hard closing. 
    * @side Client/Server
    * @return socket_t - returns SUCCESS if you are able to attempt
    *    a closure with the fd passed, else return FAIL.
    */
   //command error_t Transport.release(socket_t fd);

   /**
    * Listen to the socket and wait for a connection.
    * @param
    *    socket_t fd: file descriptor that is associated with the socket
    *       that you are hard closing. 
    * @side Server
    * @return error_t - returns SUCCESS if you are able change the state 
    *   to listen else FAIL.
    */
   command error_t Transport.listen(socket_t fd){
      socket_store_t * socketHolder ;
      if (!(call Connections.contains(fd)))
         return FAIL;
      socketHolder = call Connections.getPointer(fd);
      if(socketHolder->state == LISTEN){
        dbg(TRANSPORT_CHANNEL,"Socket is already listening\n");
        return FAIL;
      }
      else{
        dbg (TRANSPORT_CHANNEL, "Change Socket State from %d to Listen:%d\n",socketHolder->state, LISTEN);
        socketHolder->state = LISTEN;
        return SUCCESS;
      }
   }

}