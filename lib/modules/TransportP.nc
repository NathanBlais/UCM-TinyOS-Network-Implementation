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

  uses interface Timer<TMilli> as sendPacketTimer;
  uses interface Timer<TMilli> as sendDataTimer;

 }

 implementation{

    // Globals

    const socket_t NULLSocket = 0;
    tcpHeader sendPackageTCP;
    pack sendIPpackage;
    uint8_t * Empty;

    // Prototypes

    error_t sendData();
    void sendDataDone(error_t err);

    error_t sendPacket();
    void sendPacketDone(error_t err);


    void makeTCPpack(tcpHeader *Package, uint8_t src, uint8_t dest, uint8_t flag, uint8_t seq, uint8_t ack, uint8_t len, uint8_t ad_win, uint8_t* payload, uint8_t length);
    void makeIPpack(pack *Package, tcpHeader  *myTCPpack, socket_store_t *sock, uint8_t length);




  command socket_t Transport.socket(socket_t fd){
    //uint8_t i;
    dbg(TRANSPORT_CHANNEL,"Transport.socket() Called\n");
    if(call Connections.contains(0)) { //if there is room
      if(!(call Connections.contains(fd))) 
        return fd;
      else{
        dbg(TRANSPORT_CHANNEL,"Failed: port %d is not available\n", fd);
        return NULLSocket;
      }

    //  for(i=1; i-1 <= call Connections.size(); i++){
    //    if(!(call Connections.contains(i)))               //Brobubly Broken
    //      return (socket_t) i;
    //  }
    }
    dbg(TRANSPORT_CHANNEL,"Failed: No sockets are available\n");
    return NULLSocket;
  }

  command error_t Transport.bind(socket_t fd, socket_addr_t *addr){
    socket_store_t TCB;    //Transmission Control Block
    //int i = 0;
    //Checkers 
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
    // for (i = 0; i < SOCKET_BUFFER_SIZE; i++){ //I don't know if I need to fill this
		// 	TCB.sendBuff[i] = 0;
		// }
    TCB.lastWritten = 0;
    TCB.lastAck = 0;
    TCB.lastSent = 0;
    // This is the receiver portion
    // for (i = 0; i < SOCKET_BUFFER_SIZE; i++){ //I don't know how this should be used or mannaged
    //   TCB.rcvdBuff[i] = 0;
		// }
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

  command socket_t Transport.accept(socket_t fd, pack* myPacket){
    socket_store_t * mySocket;
    uint8_t lastRcvd;
    uint8_t nextExpected;
    tcpHeader * myTcpHeader = (tcpHeader*) myPacket->payload;
    mySocket = call Connections.getPointer(fd);
    dbg(TRANSPORT_CHANNEL, "STATE: %d in accept \n",mySocket->state);

    lastRcvd = myTcpHeader->Seq_Num; // do i need this?
        
    mySocket->state = SYN_RCVD;

    mySocket->dest.port= myTcpHeader->Src_Port;
    mySocket->dest.addr= myPacket->src;
    mySocket->nextExpected = 1;
        
    makeTCPpack(&sendPackageTCP,               //tcp_pack *Package
                mySocket->src,
                mySocket->dest.port,                    //uint8_t des //not sure
                SYN,                           //uint8_t flag
                lastRcvd,                             //uint8_t seq
                lastRcvd, //socketHolder->nextExpected///uint8_t ack
                0,                             //uint8_t HdrLen
                1,                             //uint8_t advertised_window
                Empty,                            //uint8_t* payload
                0);                            //uint8_t length
    makeIPpack(&sendIPpackage, &sendPackageTCP, mySocket, PACKET_MAX_PAYLOAD_SIZE);
    //call timer
    //send packet
    call Sender.send(sendIPpackage, call DistanceVectorRouting.GetNextHop(5));
    // i need to get the new socket......but how?

    return fd;
  }


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
  command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){
      socket_store_t * curSocket = call Connections.getPointer(fd);
      uint8_t written;

    dbg(TRANSPORT_CHANNEL,"Transport.write() Called\n");
    if (buff == NULL || bufflen < 1){
      return 0;
    }

    //NOTE: this will not work if you try to write too much information back to back
    //for that we need to get the amount of info already on the buffer and make that the
    // max amount you can write instead.
    if (bufflen > SOCKET_BUFFER_SIZE){
      written = SOCKET_BUFFER_SIZE - bufflen;
    }
    else{
      written = bufflen;
    }
    memcpy((curSocket->sendBuff), buff, written);
    dbg(TRANSPORT_CHANNEL, "Message to send is %s\n", curSocket->sendBuff);

     // call a sender timmer
     //    call sendDataTimer.startPeriodic(2 * tempSocket.RTT);
    call sendDataTimer.startPeriodic(80000);
    return written;
  }

  event void sendDataTimer.fired(){
    sendData();
  }

  void sendDataDone(error_t err){
    if(err == SUCCESS){
      socket_store_t * socketHolder;
      uint8_t TempSendBuff[SOCKET_BUFFER_SIZE];
      uint8_t buffSize, sendSize, TCPflag, j, i;
      uint8_t size = call Connections.size();
      uint32_t * keys = call Connections.getKeys();

      if(size == 0){
        call sendDataTimer.stop();
      }
      dbg(TRANSPORT_CHANNEL," ATTEMPTING TO SEND DATA\n");
      for(i=0;i<size;i++){
        socketHolder = call Connections.getPointer(keys[i]);
        dbg(TRANSPORT_CHANNEL,"keys[i]: %d\n", keys[i]);
        dbg(TRANSPORT_CHANNEL," How many times in the loop: %d\n", i);

        dbg(TRANSPORT_CHANNEL,"socketHolder->lastSent: %d | socketHolder->lastAck %d\n",socketHolder->lastSent,socketHolder->lastAck );
        
        dbg(TRANSPORT_CHANNEL,"socketHolder->sendBuff %s\n",socketHolder->sendBuff );


        if(socketHolder->state == ESTABLISHED &&
          socketHolder->lastSent == socketHolder->lastAck &&
          socketHolder->sendBuff != '\0')
          { //if true send data
                dbg(TRANSPORT_CHANNEL," Does it enter here?\n");
          for(buffSize=0; socketHolder->sendBuff[buffSize] != '\0'; buffSize++ ){} //calculates the size of the buffer
          if(buffSize > TCP_PACKET_MAX_PAYLOAD_SIZE){//if size of buffer is > TCP_PACKET_MAX_PAYLOAD_SIZE
            sendSize = TCP_PACKET_MAX_PAYLOAD_SIZE;
            TCPflag = ACK;
          }  
          else { //send normaly with PUSH flag <- let it know it is the end of the data send
            sendSize = buffSize;
            TCPflag = PUSH;
          }
          //edit socket for correct data

          if (socketHolder->lastSent == 0) {socketHolder->lastSent = 1;}
          else{socketHolder->lastSent = 0;}
          
          makeTCPpack(&sendPackageTCP,               //tcp_pack *Package
                      socketHolder->src,             //uint8_t src
                      socketHolder->dest.port,    //??   //uint8_t des
                      TCPflag,                           //uint8_t flag
                      socketHolder->lastSent,           //uint8_t seq
                      0, /*socketHolder->nextExpected*///uint8_t ack
                      sendSize,                        //uint8_t HdrLen
                      1,                               //uint8_t advertised_window
                      socketHolder->sendBuff,          //uint8_t* payload
                      sendSize);                            //uint8_t length
          makeIPpack(&sendIPpackage, &sendPackageTCP, socketHolder, PACKET_MAX_PAYLOAD_SIZE); //maybe reduce the PACKET_MAX_PAYLOAD_SIZE
          
          dbg(TRANSPORT_CHANNEL," Sending Message: %s\n",sendPackageTCP.payload);

          //send packet
          call Sender.send(sendIPpackage, call DistanceVectorRouting.GetNextHop(socketHolder->dest.addr));

          //set timmer to posibly resend packet
          dbg(TRANSPORT_CHANNEL," Sendt Message: %s\n",sendPackageTCP.payload);

          //edit buffer
          if(buffSize > TCP_PACKET_MAX_PAYLOAD_SIZE){
          memcpy(TempSendBuff, &((socketHolder->sendBuff)[sendSize]), buffSize - sendSize);
          dbg(TRANSPORT_CHANNEL," TempSendBuff: %s\n",TempSendBuff);
          }

          else{
              for (i = 0; i < SOCKET_BUFFER_SIZE; i++){ //I don't know if I need to fill this
                socketHolder->sendBuff[i] = 0;
              }
          }


          //TempSendBuff
          //memcpy(socketHolder->sendBuff, (socketHolder->sendBuff)[sendSize], buffSize);
          //memcpy(socketHolder->sendBuff, &((socketHolder->sendBuff)[sendSize, buffSize]), buffSize - sendSize);

        }
      }
    }
  }//end of: void sendDataDone(error_t err)

  task void sendDataTask(){

    sendDataDone(SUCCESS);
  }

  error_t sendData(){
    post sendDataTask();
    return SUCCESS;
  }

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

      dbg(TRANSPORT_CHANNEL, "Transport.receive() Called\n");


      // if(curConection->nextExpected != mySegment->Seq_Num){
      //   dbg(TRANSPORT_CHANNEL, "Recived packet with unexpected SEQ #\n");
      //   return FAIL;

      // }

      //put some checks here

      //check if the ack of the packet is the expected ack
      
      dbg(TRANSPORT_CHANNEL, "STATE: %d \n",curConection->state);

      switch (curConection->state) { 
      case CLOSED: //Don't know what do do with it yet
        break;  
      case LISTEN:
        dbg(TRANSPORT_CHANNEL, "Transport Called Listen\n");
        if(mySegment->Flags == URG){}
        else if(mySegment->Flags == ACK){} //DONT USE
        else if(mySegment->Flags == PUSH){} //I DONT KNOW
        else if(mySegment->Flags == RESET){}
        else if(mySegment->Flags == SYN){
          call Transport.accept(curConection->src, myMsg);
          return SUCCESS;
        } //<- the main one
        else if(mySegment->Flags == FIN){} //I DONT KNOW
        else{}//Wrong info
        
        break;                
      case SYN_SENT:
            //put some checks here
        if(mySegment->Flags & ( SYN | ACK )) {
          //stop timmer
            //change the state of the socket to established
          curConection->state = ESTABLISHED;
          curConection->lastRcvd = mySegment->Seq_Num;
          curConection->lastSent = 1;
          curConection->nextExpected = 1;
          curConection->effectiveWindow = mySegment->Advertised_Window;
            //curConection.RTT = call LocalTime.get() - tempSocket.RTT + 10;


        //Make the packet to send
        makeTCPpack(&sendPackageTCP,               //tcp_pack *Package
                    mySegment->Dest_Port,             //uint8_t src
                    mySegment->Src_Port,    //??                //uint8_t des
                    ACK,                           //uint8_t flag
                    1,                             //uint8_t seq
                    1, /*socketHolder->nextExpected*///uint8_t ack
                    0,                             //uint8_t HdrLen
                    1,                             //uint8_t advertised_window
                    Empty,                            //uint8_t* payload
                    0);                            //uint8_t length
        makeIPpack(&sendIPpackage, &sendPackageTCP, curConection, PACKET_MAX_PAYLOAD_SIZE); //maybe reduce the PACKET_MAX_PAYLOAD_SIZE

        //save a copy of the packet to posibly be sent by a timmer
        call Sender.send(sendIPpackage, call DistanceVectorRouting.GetNextHop(myMsg->src));
        return SUCCESS;
          //optionally do some RTT stuff here
          
          //send out inital ack

          //set timmer

          //call to start sending packets from que.


        }
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == PUSH){}
        if(mySegment->Flags == RESET){}
        if(mySegment->Flags == FIN){}
        break; 
      case SYN_RCVD:
                      //put some checks here
        if(mySegment->Flags & ( SYN | ACK )) {
          //stop timmer
          //change the state of the socket to established
          curConection->state = ESTABLISHED;

          curConection->lastAck = 1;
          curConection->lastRcvd = mySegment->Seq_Num;
          curConection->nextExpected = 0;

          //Make the packet to send
          makeTCPpack(&sendPackageTCP,               //tcp_pack *Package
                    mySegment->Dest_Port,             //uint8_t src
                    mySegment->Src_Port,    //??                //uint8_t des
                    ACK,                           //uint8_t flag
                    1,                             //uint8_t seq
                    1, /*socketHolder->nextExpected*///uint8_t ack
                    0,                             //uint8_t HdrLen
                    1,                             //uint8_t advertised_window
                    Empty,                            //uint8_t* payload
                    0);                            //uint8_t length
          makeIPpack(&sendIPpackage, &sendPackageTCP, curConection, PACKET_MAX_PAYLOAD_SIZE); //maybe reduce the PACKET_MAX_PAYLOAD_SIZE

        //save a copy of the packet to posibly be sent by a timmer
        call Sender.send(sendIPpackage, call DistanceVectorRouting.GetNextHop(myMsg->src));
        return SUCCESS;
        }
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == PUSH){}
        if(mySegment->Flags == RESET){}
        if(mySegment->Flags == FIN){}
        break; 
      case ESTABLISHED:
        if(mySegment->Flags == URG){}
        if(mySegment->Flags == ACK){
          curConection->lastAck = mySegment->Acknowledgment;
          curConection->lastRcvd = mySegment->Seq_Num;
          if(mySegment->Len == 0){ //this is a normal ack pack

            //update socket
          }
          else{ // has data          
          curConection->effectiveWindow = mySegment->Advertised_Window;
          call Transport.read(curConection->src, mySegment->payload, mySegment->Len);
          //store pack for resend

          //send back an ack packet

          }


          //if the packet has a len of 0

          //change ack for socket
          curConection->lastAck = mySegment->Acknowledgment;
          
          //curConection->nextExpected = ;

          //if you have data to send, send it else just send normal ack packet
        }
        if(mySegment->Flags == PUSH){
            //update socket
          //read the packet 
            dbg(TRANSPORT_CHANNEL, "Message Recived:%s\n",mySegment->payload);

          call Transport.read(curConection->src, mySegment->payload, mySegment->Len);
          
          //print out entire buffer
          dbg(TRANSPORT_CHANNEL, "\tFinished reciving Message\n");
          dbg(TRANSPORT_CHANNEL, "\t\tMessage:%s\n",curConection->rcvdBuff);

          //update last sent
          if (curConection->lastSent == 0) {curConection->lastSent = 1;}
          else{curConection->lastSent = 0;}

          //Make the ACK packet to send
          makeTCPpack(&sendPackageTCP,               //tcp_pack *Package
                    mySegment->Dest_Port,             //uint8_t src
                    mySegment->Src_Port,    //??                //uint8_t des
                    ACK,                           //uint8_t flag
                    curConection->lastSent,                             //uint8_t seq
                    1, /*socketHolder->nextExpected*///uint8_t ack
                    0,                             //uint8_t HdrLen
                    1,                             //uint8_t advertised_window
                    Empty,                            //uint8_t* payload
                    0);                            //uint8_t length
          makeIPpack(&sendIPpackage, &sendPackageTCP, curConection, PACKET_MAX_PAYLOAD_SIZE); //maybe reduce the PACKET_MAX_PAYLOAD_SIZE          
          
          call Sender.send(sendIPpackage, call DistanceVectorRouting.GetNextHop(myMsg->src));
          return SUCCESS;

        }
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
      return FAIL;
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
  command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen){
    uint8_t buffSize, i;
    socket_store_t * socketHolder =  call Connections.getPointer(fd);

    dbg(TRANSPORT_CHANNEL, "Transport Called Read\n");
    for(buffSize=0; socketHolder->sendBuff[buffSize] != '\0'; buffSize++ ){} //calculates the size of the buffer

    // for (i = 0; i < bufflen; i++){
    //   socketHolder->rcvdBuff[buffSize + i] = buff[i] ;
		// }

    strcat(socketHolder->rcvdBuff, buff);

    if (socketHolder->lastRead == 0) {socketHolder->lastRead = 1;}
    else{socketHolder->lastRead = 0;}
    if (socketHolder->nextExpected == 0) {socketHolder->nextExpected = 1;}
    else{socketHolder->nextExpected = 0;}

   }

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
                    0,                             //uint8_t HdrLen
                    1,                             //uint8_t advertised_window
                    Empty,                            //uint8_t* payload
                    0);                            //uint8_t length
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


  event void sendPacketTimer.fired(){
    sendPacket();
  }

  void sendPacketDone(error_t err){
    if(err == SUCCESS){
      socket_store_t * socketHolder;

      uint8_t buffSize, sendSize, TCPflag, j, i;
      uint8_t size = call Connections.size();
      uint32_t * keys = call Connections.getKeys();

      dbg(TRANSPORT_CHANNEL," ATTEMPTING TO RE-SEND DATA\n");
      for(i=0;i<size;i++){
        socketHolder = call Connections.getPointer(keys[i]);
        dbg(TRANSPORT_CHANNEL,"keys[i]: %d\n", keys[i]);
        dbg(TRANSPORT_CHANNEL," How many times in the loop: %d\n", i);

        dbg(TRANSPORT_CHANNEL,"socketHolder->lastSent: %d | socketHolder->lastAck %d\n",socketHolder->lastSent,socketHolder->lastAck );
        
        dbg(TRANSPORT_CHANNEL,"socketHolder->sendBuff %s\n",socketHolder->sendBuff );


        if(socketHolder->state == ESTABLISHED &&
          socketHolder->lastSent == socketHolder->lastAck &&
          socketHolder->sendBuff != '\0')
          { //if true send data
                dbg(TRANSPORT_CHANNEL," Does it enter here?\n");
          for(buffSize=0; socketHolder->sendBuff[buffSize] != '\0'; buffSize++ ){} //calculates the size of the buffer
          if(buffSize > TCP_PACKET_MAX_PAYLOAD_SIZE){//if size of buffer is > TCP_PACKET_MAX_PAYLOAD_SIZE
            sendSize = TCP_PACKET_MAX_PAYLOAD_SIZE;
            TCPflag = ACK;
          }  
          else { //send normaly with PUSH flag <- let it know it is the end of the data send
            sendSize = buffSize;
            TCPflag = PUSH;
          }
          //edit socket for correct data

          if (socketHolder->lastSent == 0) {socketHolder->lastSent = 1;}
          else{socketHolder->lastSent = 0;}
          
          makeTCPpack(&sendPackageTCP,               //tcp_pack *Package
                      socketHolder->src,             //uint8_t src
                      socketHolder->dest.port,    //??   //uint8_t des
                      TCPflag,                           //uint8_t flag
                      socketHolder->lastSent,           //uint8_t seq
                      0, /*socketHolder->nextExpected*///uint8_t ack
                      sendSize,                        //uint8_t HdrLen
                      1,                               //uint8_t advertised_window
                      socketHolder->sendBuff,          //uint8_t* payload
                      sendSize);                            //uint8_t length
          makeIPpack(&sendIPpackage, &sendPackageTCP, socketHolder, PACKET_MAX_PAYLOAD_SIZE); //maybe reduce the PACKET_MAX_PAYLOAD_SIZE
          
          dbg(TRANSPORT_CHANNEL," Sending Message: %s\n",sendPackageTCP.payload);

          //send packet
          call Sender.send(sendIPpackage, call DistanceVectorRouting.GetNextHop(socketHolder->dest.addr));

          //set timmer to posibly resend packet
          dbg(TRANSPORT_CHANNEL," Sendt Message: %s\n",sendPackageTCP.payload);

          //edit buffer
          if(buffSize > TCP_PACKET_MAX_PAYLOAD_SIZE){
          memcpy(TempSendBuff, &((socketHolder->sendBuff)[sendSize]), buffSize - sendSize);
          dbg(TRANSPORT_CHANNEL," TempSendBuff: %s\n",TempSendBuff);
          }

          else{
              for (i = 0; i < SOCKET_BUFFER_SIZE; i++){ //I don't know if I need to fill this
                socketHolder->sendBuff[i] = 0;
              }
          }


          //TempSendBuff
          //memcpy(socketHolder->sendBuff, (socketHolder->sendBuff)[sendSize], buffSize);
          //memcpy(socketHolder->sendBuff, &((socketHolder->sendBuff)[sendSize, buffSize]), buffSize - sendSize);

        }
      }
    }
  }//end of: void sendPacketDone(error_t err)

  task void sendPackeTask(){

    sendPacketDone(SUCCESS);
  }

  error_t sendPacket(){
    post sendDataTask();
    return SUCCESS;
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
    Package->src = (uint8_t)TOS_NODE_ID;
    Package->dest = sock->dest.addr;
    Package->TTL = MAX_TTL;
    Package->seq = sock->lastSent; //finish this
    Package->protocol = PROTOCOL_TCP;
    memcpy(Package->payload, myTCPpack, length);
  }

}