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
  //Uses interface Receive as Receiver;
  //Uses interface AMPacket;
  
  //Uses the (DVR) interface to know where to forward packets.
  uses interface DistanceVectorRouting;

  uses interface Hashmap<socket_store_t> as Connections; // hash table: list of connections

  uses interface LocalTime<TMilli>;
//   uses interface Timer<TMilli> as sendPacketTimer;
//   uses interface Timer<TMilli> as sendDataTimer;

  uses interface Queue<pack*>;
  uses interface Pool<pack>;
  //uses interface SendQueue<sendTCPInfo*> as SendQueue;
  //uses interface SendPool<pack> as SendPool;

 }


 /* --------- Questions Area --------- *\
✱This is where we put our general questions
        ➤•⦿◆ →←↑↓↔︎↕︎↘︎⤵︎⤷⤴︎↳↖︎⤶↲↱⤻

    ➤ We should set up a generic packet send buffer
        •
    
    ➤ 
        •
        •

    ➤

    ➤


\* --------- Questions Area --------- */

 //need a send_to_buffer
 //need a send_out


  implementation{    

    // Globals

    const socket_t NULLSocket = 0;
    uint8_t *Empty;
    uint16_t ipSeq = 1;

    // Prototypes

    error_t receive(pack* package);
    void makeIPpack(pack *Package, tcpHeader *myTCPpack, socket_store_t *sock, uint8_t length);


    error_t send_out(socket_t socKey, uint8_t flag, uint8_t seq, uint8_t ack, uint8_t* payload, uint8_t length){
        tcpHeader sendPackageTCP;
        pack sendIPpackage;
        socket_store_t * socketHolder = call Connections.getPointer(socKey);

        dbg(TRANSPORT_CHANNEL,"error_t send Called\n");

        switch (socketHolder->state)
            { 
            case CLOSED: 
                dbg(TRANSPORT_CHANNEL,"error:  connection does not exist\n");
                return FAIL;
                break;  
            default:
                //dbg(TRANSPORT_CHANNEL, "WRONG_STATE_ERROR: \"%d\" is an incompatable state or does not match any known states.\n", socketHolder->state);
                //return FAIL;
                break;
        }

        /*Make the TCP Packet*/
        sendPackageTCP.Src_Port = socketHolder->src;
        sendPackageTCP.Dest_Port = socketHolder->dest.port;
        sendPackageTCP.Flags = flag;
        sendPackageTCP.Seq_Num = seq;
        sendPackageTCP.Acknowledgment = ack;
        sendPackageTCP.Len = length;
        sendPackageTCP.Advertised_Window = socketHolder->effectiveWindow;
        memcpy(sendPackageTCP.payload, payload, length);
        /*END OF: Make the TCP Packet*/
        makeIPpack(&sendIPpackage, &sendPackageTCP, socketHolder, PACKET_MAX_PAYLOAD_SIZE); //maybe reduce the PACKET_MAX_PAYLOAD_SIZE
        ipSeq = ipSeq + 1;

        call Sender.send(sendIPpackage, call DistanceVectorRouting.GetNextHop(socketHolder->dest.addr));

        //update socket -------------------------------------------
        socketHolder->lastSent = sendPackageTCP.Seq_Num;

        // if (socketHolder->lastSent == 0) {socketHolder->nextExpected = 0;}
        // else{socketHolder->nextExpected = 1;}    

        //save a copy of the packet to be re-sent by a timmer and set RTT & TTD lastTimeSent
        socketHolder->RTT = (socketHolder->lastTimeRecived - socketHolder->lastTimeSent) + call LocalTime.get() + 300;
        socketHolder->TTD = (socketHolder->RTT) * 3;
        return SUCCESS;

    }

    error_t send_buff(socket_t socKey, uint8_t flag, uint8_t seq, uint8_t ack, uint8_t* payload, uint8_t length){
        send_out(socKey, flag, seq, ack, payload, length);
        return SUCCESS;
    }

    // error_t send_data(/*Some Junk*/){
    //     socket_store_t * socketHolder ;
    //     if (!(call Connections.contains(fd))) return FAIL;
    //     socketHolder = call Connections.getPointer(fd);

    //     switch (socketHolder->state)
    //     { 
    //     case CLOSED: 
    //         dbg(TRANSPORT_CHANNEL,"error:  connection does not exist\n");
    //         return FAIL;
    //         break;  
    //     case LISTEN:
    //     case SYN_SENT:
    //     case SYN_RCVD:


    //      /*re-Queue the data for transmission 
    //       If no space to queue, respond with "error: insufficient
    //      resources".*/
    //     case ESTABLISHED:
    //     case CLOSE_WAIT:

    //     //send data

    //      /*Segmentize the buffer and send it with a piggybacked
    //      acknowledgment (acknowledgment value = RCV.NXT).  If there is
    //      insufficient space to remember this buffer, simply return
    //      "error: insufficient resources".

    //      If the urgent flag is set, then SND.UP <- SND.NXT and set the
    //      urgent pointer in the outgoing segments.*/

    //     case LAST_ACK:
    //     case FIN_WAIT_1:
    //     case FIN_WAIT_2:
    //     case TIME_WAIT:
    //     case CLOSING:
    //         dbg(TRANSPORT_CHANNEL, "error: connection closing\n");


    //     Return "error: connection closing" and do not service request.

    //     default:
    //         dbg(TRANSPORT_CHANNEL, "WRONG_STATE_ERROR: \"%d\" is an incompatable state or does not match any known states.\n", socketHolder->state);
    //         return FAIL;
    //         break;
    //     }
    // }

    command socket_t Transport.socket(socket_t fd){
        dbg(TRANSPORT_CHANNEL,"Transport.socket() Called\n");
        if(call Connections.contains(0)) { //if there is room
        if(!(call Connections.contains(fd))) 
            return fd;
        else{
            dbg(TRANSPORT_CHANNEL,"Failed: port %d is not available\n", fd);
            return NULLSocket;
        }
        }
        dbg(TRANSPORT_CHANNEL,"Failed: No sockets are available\n");
        return NULLSocket;
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr){
        socket_store_t TCB;//Transmission Control Block

        //Check if values are valid
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

        //Make Socket and Update Values
        dbg(TRANSPORT_CHANNEL,"Transport.bind() Called\n");
        TCB.src = fd;
        TCB.dest = *addr;
        TCB.state = CLOSED;
        TCB.effectiveWindow = 1;  //NOTE:We Need to replace this value
        //Add call to set up Sliding Window

        call Connections.insert(fd, TCB);//insert socket into Hash

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
        socket_store_t * socketHolder;
        tcpHeader * myTcpHeader = (tcpHeader*) myPacket->payload;

        if (!(call Connections.contains(fd))) return 0; //Checks if the socket exists

        socketHolder = call Connections.getPointer(fd);
        switch (socketHolder->state) { 
            case LISTEN:
                socketHolder->dest.port= myTcpHeader->Src_Port;
                socketHolder->dest.addr= myPacket->src;
                break;
            default:
                break;
        }
        return fd;
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){
        socket_store_t * socketHolder ;
        uint8_t written;
        if (!(call Connections.contains(fd))) return FAIL;
        socketHolder = call Connections.getPointer(fd);

        dbg(TRANSPORT_CHANNEL,"Transport.write() Called\n");
        if (buff == NULL || bufflen < 1) return 0;
        if (!(call Connections.contains(fd))) return 0;

        switch (socketHolder->state)
        { 
        case CLOSED: 
            dbg(TRANSPORT_CHANNEL,"error:  connection does not exist\n");
            break;  
        case LISTEN:
        case SYN_SENT:
        case SYN_RCVD:
        case ESTABLISHED:
        case CLOSE_WAIT:
            //get size of buffer
            for(written=0; socketHolder->sendBuff[written] != '\0'; written++){} 

            if (bufflen > written){
               // will write the max ammount
            }
            else{
                written = bufflen;
            }
            memcpy((socketHolder->sendBuff), buff, written);
            dbg(TRANSPORT_CHANNEL, "Message to send is %s\n", socketHolder->sendBuff);

            //call sendDataTimer.startPeriodic(81000); //could be set to a diffrent number
            return written;

        case LAST_ACK:
        case FIN_WAIT_1:
        case FIN_WAIT_2:
        case TIME_WAIT:
        case CLOSING:
            dbg(TRANSPORT_CHANNEL,"error: connection closing\n");
            break;
        default:
            dbg(TRANSPORT_CHANNEL, "WRONG_STATE_ERROR: \"%d\" is an incompatable state or does not match any known states.\n", socketHolder->state);
            break;
        }
        return 0;
    }

    error_t receive(pack* package)
    {
        pack* myMsg=(pack*) package;
        uint8_t seq;
        tcpHeader* mySegment = (tcpHeader*) myMsg->payload;
        socket_store_t * curConection = call Connections.getPointer(mySegment->Dest_Port);

        dbg(TRANSPORT_CHANNEL, "Transport.receive() Called\n");
        dbg(TRANSPORT_CHANNEL, "STATE: %d | FLAG: %d\n", curConection->state, mySegment->Flags);

        // printTCP(mySegment);
        // printSocket(mySegment->Dest_Port);

        dbg(TRANSPORT_CHANNEL, "INCOMING SEQ #: %d\n",mySegment->Seq_Num );

        // //TO_DO: add check here to see if the packet has been seen before

        curConection->lastRcvd = mySegment->Seq_Num;
        curConection->LastRecivedIPpack = *myMsg;

        // curConection->lastTimeRecived = call LocalTime.get();

        //make sure only the sender is updating their   curConection->effectiveWindow

        switch (curConection->state) {
            case CLOSED:
            dbg(TRANSPORT_CHANNEL, "State is Closed\n");
            //Acording to RFC - 793:
            //An incoming segment not containing a RST causes a RST to be sent in response. 
            //^ we will ignore this
            return SUCCESS;
            break;  
            case LISTEN:
            if(mySegment->Flags == RESET){/*ignore*/}
            else if(mySegment->Flags == ACK){/* Can't have ACK send Pack:<SEQ=SEG.ACK><CTL=RST>*/}
            else if(mySegment->Flags == SYN){
                call Transport.accept(curConection->src, myMsg);

                seq = mySegment->Seq_Num;
                send_buff(curConection->src, SYN+ACK, seq, 0, Empty, 0);
                curConection->nextExpected = 1; //Replace this
                curConection->state = SYN_RCVD;
                dbg(TRANSPORT_CHANNEL, "STATE: LISTEN -> SYN_RCVD\n");

                return SUCCESS;
            }
            else{ //Wrong info
                return SUCCESS;
            }
            break; 
            case SYN_SENT:
                //put some checks here
            if(mySegment->Flags & ( SYN | ACK )) {
                //dbg(TRANSPORT_CHANNEL, "curConection->lastSent %d < mySegment->Acknowledgment %d\n", curConection->lastSent, mySegment->Acknowledgment);

                //any segments on the retransmission queue which are thereby acknowledged should be removed.
                dbg(TRANSPORT_CHANNEL, "curConection->lastSent %d  curConection->lastRcvd %d\n", curConection->lastSent, curConection->lastRcvd);

                if(curConection->lastSent == curConection->lastRcvd){
                    dbg(TRANSPORT_CHANNEL, "STATE: SYN_SENT -> ESTABLISHED\n");
                    curConection->state = ESTABLISHED;

                    if(curConection->lastSent == 0){seq = 1;}
                    else{seq = 0;}

                    send_buff(curConection->src, ACK, seq, 0, Empty, 0);
                    curConection->nextExpected = seq;

                    return SUCCESS;
                }

                //TO_DO:call event to start sending packets from que.
            }
            else return SUCCESS;
            break; 

            ///new bits
        }

        //check sequence number HERE
        if(curConection->nextExpected != mySegment->Seq_Num){
            dbg(TRANSPORT_CHANNEL, "curConection->nextExpected %d  curConection->lastRcvd %d\n", curConection->nextExpected, curConection->lastRcvd);
            dbg(TRANSPORT_CHANNEL, "Recived packet with unexpected SEQ #\n");
            return SUCCESS;
        }

        switch (curConection->state) {

            case SYN_RCVD:
                //put some checks here
                if(mySegment->Flags & ( SYN | ACK )) {
                    curConection->state = ESTABLISHED;
                    dbg(TRANSPORT_CHANNEL, "STATE: SYN_RCVD -> ESTABLISHED\n");

                    seq = mySegment->Seq_Num;
                    send_buff(curConection->src, ACK, seq, 0, Empty, 0); //update this
                    curConection->nextExpected = 0; //Replace this

                    return SUCCESS;
                }
                else return SUCCESS;
                break;
            case LAST_ACK:
                if(mySegment->Flags == ACK && curConection->nextExpected == mySegment->Seq_Num){
                    curConection->state=CLOSED;
                    dbg(TRANSPORT_CHANNEL, "STATE: LAST_ACK -> CLOSED\n");
                    break;
                }             
            case FIN_WAIT_1:
                if(mySegment->Flags == ACK){
                    curConection->state = FIN_WAIT_2;
                    dbg(TRANSPORT_CHANNEL, "STATE: FIN_WAIT_1 -> FIN_WAIT_2\n");
                    return SUCCESS;
                }
            case FIN_WAIT_2:
                if(mySegment->Flags == FIN){
                    curConection-> state = TIME_WAIT;
                    dbg(TRANSPORT_CHANNEL, "STATE: FIN_WAIT_2 -> TIME_WAIT\n");

                    send_buff(curConection->src, ACK, curConection->nextSend, curConection->nextExpected, Empty, 0); //update this

                //set a timer that eventually closes the socket
                return SUCCESS;
                }
            case CLOSE_WAIT:
            case ESTABLISHED: //NOTE: everything below should be updated
                if(mySegment->Flags == ACK){
                    if(mySegment->Len == 0){ //this is a normal ack pack
                        //update socket
                        //stop resend for data
                    }
                    else{ // has data   //Only need to ipmlement this if you send more than one packet of data       
                        //update socket
                        call Transport.read(curConection->src, mySegment, mySegment->Len);

                        //make ack packet
                        //store pack for resend
                        //send back an ack packet
                    }
                }
                else if(mySegment->Flags == PUSH){
                    dbg(TRANSPORT_CHANNEL, "Message Recived:%s\n",mySegment->payload);

                    call Transport.read(curConection->src, mySegment, mySegment->Len);
                    //print out entire buffer
                    dbg(TRANSPORT_CHANNEL, "\tFinished reciving Message\n");
                    dbg(TRANSPORT_CHANNEL, "\t\tMessage:%s\n",curConection->rcvdBuff);

                    send_buff(curConection->src, ACK, curConection->nextSend, curConection->nextExpected, Empty, 0); //update this
                    return SUCCESS;
                }
                else if(mySegment->Flags == FIN){
                    curConection-> state = CLOSE_WAIT;
                    dbg(TRANSPORT_CHANNEL, "STATE: ESTABLISHED -> CLOSE_WAIT\n");

                    send_buff(curConection->src, ACK, curConection->nextSend, curConection->nextExpected, Empty, 0); //update this

                    //call timer first or after?
                    call Transport.close(curConection->src); 
                    //timer? or command most likey command
                }
                else if(mySegment->Flags == RESET){}
                else if(mySegment->Flags == URG){}
                else return FAIL;
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

    task void receiveBufferTask(){
        // If we have a values in our queue and the radio is not busy, then
        // attempt to send a packet.
        if(!call Queue.empty()){
            pack *info;
            // We are peeking since, there is a possibility that the value will not
            // be successfuly sent and we would like to continue to attempt to send
            // it until we are successful. There is no limit on how many attempts
            // can be made.
            info = call Queue.head();

            // Attempt to send it.
            if(SUCCESS == receive(info)){
                //Release resources used if the attempt was successful
                call Queue.dequeue();
                call Pool.put(info);
            }
        }
    }

    command error_t Transport.receiveBuffer(pack* package){   
        if(!call Pool.empty()){
            pack *input;
            input = call Pool.get();
            memcpy(input, package, PACKET_MAX_PAYLOAD_SIZE);

            // Now that we have a value from the pool we can put it into our queue.
            // This is a FIFO queue.
            call Queue.enqueue(input);

            // Start a send task which will be delayed.
            post receiveBufferTask();

            return SUCCESS;
        }
        return FAIL;
    } 
        
    command uint16_t Transport.read(socket_t fd, tcpHeader *tcpSegment, uint16_t bufflen){
        uint8_t buffSize;
        socket_store_t * socketHolder =  call Connections.getPointer(fd);
        uint8_t *buff = tcpSegment->payload;

        dbg(TRANSPORT_CHANNEL, "Transport Called Read\n");

        for(buffSize=0; socketHolder->rcvdBuff[buffSize] != '\0'; buffSize++ ){} //calculates the size of the buffer
        if (bufflen > buffSize){
            // will write the max ammount
        }
        else{
            buffSize = bufflen;
        }

        strcat((socketHolder->rcvdBuff), buff);

        if (socketHolder->lastRead == 0) {socketHolder->lastRead = 1;}
        else{socketHolder->lastRead = 0;}

        return buffSize;
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr){
        socket_store_t * socketHolder ;
        uint8_t inSeq = 0; //choose inital sequence number
        if (!(call Connections.contains(fd))) return FAIL;
        socketHolder = call Connections.getPointer(fd);
        switch (socketHolder->state)
        { 
        case CLOSED: 
            socketHolder->state = SYN_SENT; //Change the state of the socket
            dbg(TRANSPORT_CHANNEL, "STATE: CLOSED -> SYN_SENT\n");
            send_buff(fd, SYN, inSeq, 0, Empty, 0); //make and send a packet //send buffer
            return SUCCESS;
            break;  
        case LISTEN:
            dbg(TRANSPORT_CHANNEL,"Socket is already listening\n");
            return FAIL;
            break;
        default:
            dbg(TRANSPORT_CHANNEL, "WRONG_STATE_ERROR: \"%d\" is an incompatable state or does not match any known states.\n", socketHolder->state);
            return FAIL;
            break;
        }
    }

    //event void connectDone(error_t e); <- might be a good idea

    command error_t Transport.close(socket_t fd)
    {
        socket_store_t * mySocket;
        uint8_t seq;
        dbg(TRANSPORT_CHANNEL, "Called Transport.close()\n");
        
        if (!(call Connections.contains(fd))) return FAIL;

        mySocket = call Connections.getPointer(fd);

        switch (mySocket->state){
            case CLOSED:
                dbg(TRANSPORT_CHANNEL, "Already closed \n");
                return FAIL;
                break;
            case LISTEN: case SYN_SENT:
                mySocket->state = CLOSED;
                dbg(TRANSPORT_CHANNEL, "Socket State: (LISTEN | SYN_SENT) -> CLOSED\n");
                return SUCCESS;
                break;
            case ESTABLISHED: //Starts the close
                //sudo Code:
                    //Set state
                    //Send packet
                    //Set timmer

                mySocket->state = FIN_WAIT_1;
                // mySocket->dest.port= myTcpHeader->Src_Port; //ask if necessary
                // mySocket->dest.addr= myPacket->src; //ask if necessary


                if(mySocket->lastSent == 0){seq = 1;}
                else{seq = 0;}

                send_buff(fd, FIN, seq, 0, Empty, 0); //update this

                return SUCCESS;
                break;
            //make timer that checks if the packets of the payload are done sending, wait APP, research to know when it's done, timer or a command
            case CLOSE_WAIT: //changes wait to FIN WAIT 2 flag fin
            //sudo Code:
                //Set state
                //Send packet
                //Set timmer
                dbg(TRANSPORT_CHANNEL, "In close CLOSE_WAIT \n");
                mySocket-> state = LAST_ACK;


                if(mySocket->lastSent == 0){seq = 1;}
                else{seq = 0;}

                send_buff(fd, FIN, seq, 0, Empty, 0); //update this
                return SUCCESS;
                break;
            default:
                dbg(TRANSPORT_CHANNEL, "WRONG_STATE_ERROR: \"%d\" is an incompatable state or does not match any known states.\n", mySocket->state);
                return FAIL;
            break;
        }
    }

    /**
        * A hard close, which is not graceful. This portion is optional.
        * @param
        *    socket_t fd: file descriptor that is associated with the socket
        *       that you are hard closing. 
        * @side Client/Server
        * @return socket_t - returns SUCCESS if you are able to attempt
        *    a closure with the fd passed, else return FAIL.
        */
    //   command error_t release(socket_t fd);

    command error_t Transport.listen(socket_t fd)
    {
        socket_store_t * socketHolder ;
        if (!(call Connections.contains(fd))) return FAIL;
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
    void makeIPpack(pack *Package, tcpHeader *myTCPpack, socket_store_t *sock, uint8_t length){
        Package->src = (uint16_t)TOS_NODE_ID;
        Package->dest = sock->dest.addr;
        Package->TTL = MAX_TTL;
        Package->seq = ipSeq; //finish this
        Package->protocol = PROTOCOL_TCP;
        memcpy(Package->payload, myTCPpack, length);
    }

}
