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
    tcpHeader sendPackageTCP;
    pack sendIPpackage;

    // Prototypes

  void makeTCPpack(tcpHeader *Package, uint8_t src, uint8_t dest, uint8_t flag, uint8_t seq, uint8_t ack, uint8_t len, uint8_t ad_win, uint8_t* payload, uint8_t length);
  void makeIPpack(pack *Package, tcpHeader  *myTCPpack, socket_store_t *sock, uint8_t length);




  command socket_t Transport.socket(){
    uint8_t i;
    dbg(TRANSPORT_CHANNEL,"Transport.socket() Called\n");
    if(call Connections.contains(0)) { //if there is room
      for(i=1; i-1 <= call Connections.size(); i++){
        if(!(call Connections.contains(i)))               //Brobubly Broken
          return (socket_t) i;
      }
    }
    dbg(TRANSPORT_CHANNEL,"Failed: No sockets are available\n");
    return NULLSocket;
  }

  command error_t Transport.bind(socket_t fd, socket_addr_t *addr){
    socket_store_t TCB;    //Transmission Control Block
    int i = 0;

    if(fd == 0 || fd > MAX_NUM_OF_SOCKETS){
      dbg(TRANSPORT_CHANNEL,"Socket:%d is not valid. Try number: 1-10\n", fd);
      return FAIL;
    }

    if(addr->addr == 0 || addr->addr > MAX_ROUTES){
      dbg(TRANSPORT_CHANNEL,"adress :%d is not valid. Try number: 1-10\n", addr->addr);
      return FAIL;
    }

    if(call Connections.contains(fd)){ //Checks if the Socket is already in use
      dbg(TRANSPORT_CHANNEL,"Socket:%d is already bound\n", fd);
      return FAIL;
    }

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
    TCB.nextExpected = 0;

    //TCB.RTT = 5000;  //NOTE:We Need to replace this value
    TCB.effectiveWindow = 1;  //NOTE:We Need to replace this value

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
      socket_store_t * curConection = call Connections.getPointer(mySegment->Dest_Port);

      switch (curConection->state) { 
      case CLOSED: //Don't know what do do with it yet
        break;  
      case LISTEN:
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == ACK){} //DONT USE
        if(mySegment->Flags == PUSH){} //I DONT KNOW
        if(mySegment->Flags == RESET){}
        if(mySegment->Flags == SYN){} //<- the main one
        if(mySegment->Flags == FIN){} //I DONT KNOW
        break;                
      case SYN_SENT:
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == ACK){}
        if(mySegment->Flags == PUSH){}
        if(mySegment->Flags == RESET){}
        if(mySegment->Flags == SYN){}
        if(mySegment->Flags == FIN){}
        break; 
      case SYN_RCVD:
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == ACK){}
        if(mySegment->Flags == PUSH){}
        if(mySegment->Flags == RESET){}
        if(mySegment->Flags == SYN){}
        if(mySegment->Flags == FIN){}
        break; 
      case ESTABLISHED:
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == ACK){}
        if(mySegment->Flags == PUSH){}
        if(mySegment->Flags == RESET){}
        if(mySegment->Flags == SYN){}
        if(mySegment->Flags == FIN){}
        break; 
      case CLOSE_WAIT:
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == ACK){}
        if(mySegment->Flags == PUSH){}
        if(mySegment->Flags == RESET){}
        if(mySegment->Flags == SYN){}
        if(mySegment->Flags == FIN){}
        break; 
      case LAST_ACK:
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == ACK){}
        if(mySegment->Flags == PUSH){}
        if(mySegment->Flags == RESET){}
        if(mySegment->Flags == SYN){}
        if(mySegment->Flags == FIN){}
        break; 
      case FIN_WAIT_1:
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == ACK){}
        if(mySegment->Flags == PUSH){}
        if(mySegment->Flags == RESET){}
        if(mySegment->Flags == SYN){}
        if(mySegment->Flags == FIN){}
        break; 
      case FIN_WAIT_2:
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == ACK){}
        if(mySegment->Flags == PUSH){}
        if(mySegment->Flags == RESET){}
        if(mySegment->Flags == SYN){}
        if(mySegment->Flags == FIN){}
        break; 
      case CLOSING:
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == ACK){}
        if(mySegment->Flags == PUSH){}
        if(mySegment->Flags == RESET){}
        if(mySegment->Flags == SYN){}
        if(mySegment->Flags == FIN){}
        break; 
      case TIME_WAIT:
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == ACK){}
        if(mySegment->Flags == PUSH){}
        if(mySegment->Flags == RESET){}
        if(mySegment->Flags == SYN){}
        if(mySegment->Flags == FIN){}
        break; 

      default:
          dbg(TRANSPORT_CHANNEL, "FLAG_ERROR: \"%d\" does not match any known commands.\n", mySegment->Flags);
          return FAIL;
          break;
      }
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
  command error_t Transport.connect(socket_t fd, socket_addr_t * addr){
    //This is set up for stop and wait 
    socket_store_t * socketHolder ;

    if (!(call Connections.contains(fd)))
      return FAIL;

    socketHolder = call Connections.getPointer(fd);

    if(socketHolder->state == LISTEN){
      dbg(TRANSPORT_CHANNEL,"Socket is already listening\n");
      return FAIL;
    }

    switch (socketHolder->state) { 
      case CLOSED: 
        socketHolder->state = SYN_SENT; //Change the state of the socket

        //the way it is currently writen assumes instant send
        //we may want to change this to be sent by a que system
        
        //Make the packet to send
        makeTCPpack(&sendPackageTCP,               //tcp_pack *Package
                    socketHolder->src,             //uint8_t src
                    addr->port,                    //uint8_t des
                    SYN,                           //uint8_t flag
                    0,                             //uint8_t seq
                    0, /*socketHolder->nextExpected*///uint8_t ack
                    1,                             //uint8_t HdrLen
                    1,                             //uint8_t advertised_window
                    "",                            //uint8_t* payload
                    1);                            //uint8_t length
        makeIPpack(&sendIPpackage, &sendPackageTCP, socketHolder, PACKET_MAX_PAYLOAD_SIZE); //maybe reduce the PACKET_MAX_PAYLOAD_SIZE

        //save a copy of the packet to posibly be sent by a timmer
        call Sender.send(sendIPpackage, call DistanceVectorRouting.GetNextHop(addr->addr));
        return SUCCESS;

        break;  
      case LISTEN:             
      case SYN_SENT:
      case SYN_RCVD:
      case ESTABLISHED:
      case CLOSE_WAIT:
      case LAST_ACK:
      case FIN_WAIT_1:
      case FIN_WAIT_2: 
      case CLOSING:
      case TIME_WAIT:
      default:
          dbg(TRANSPORT_CHANNEL, "WRONG_STATE_ERROR: \"%d\" is an incompatable state or does not match any known states.\n", socketHolder->state);
          return FAIL;
          break;
    }
  }

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

  void makeTCPpack(tcpHeader *Package, uint8_t src, uint8_t dest, uint8_t flag, uint8_t seq, uint8_t ack, uint8_t len, uint8_t ad_win, uint8_t* payload, uint8_t length){
    Package->Src_Port = src;
    Package->Dest_Port = dest;
    Package->Flags = flag;
    Package->Seq_Num = seq;
    Package->Acknowledgment = ack;

    Package->Len = len;

    Package->Advertised_Window = ad_win;
    memcpy(Package->payload, payload, length);
  }

  void makeIPpack(pack *Package, tcpHeader  *myTCPpack, socket_store_t *sock, uint8_t length){
    Package->src = TOS_NODE_ID;
    Package->dest = sock->dest.addr;
    Package->TTL = MAX_TTL;
    Package->seq = sock->lastSent; //finish this
    Package->protocol = PROTOCOL_TCP;
    memcpy(Package->payload, myTCPpack, length);
  }


}