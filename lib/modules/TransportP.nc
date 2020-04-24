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
  uses interface Timer<TMilli> as Timer;

//   uses interface List<sendTCPInf> as SendBuff;
//   uses interface List<sendTCPInf> as ReSendBuff;

  uses interface Queue<pack*>;
  uses interface Pool<pack>;
  uses interface Queue<sendTCPInfo*> as SendQueue;
  uses interface Pool<sendTCPInfo> as SendPool;

//   uses interface Queue<sendTCPInfo*> as ReSendQueue;
//   uses interface Pool<sendTCPInfo> as ReSendPool;


  //add a resend buffer

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
    uint16_t readDataToBuff(socket_t fd, tcpHeader *tcpSegment, uint16_t bufflen);
    uint8_t updateRecieverSlideWindow (socket_t fd, tcpHeader *tcpSegment);
    error_t updateSenderSlideWindow (socket_t fd, tcpHeader *tcpSegment, uint16_t bufflen);
    
    void makeIPpack(pack *Package, tcpHeader *myTCPpack, socket_store_t *sock, uint8_t length);
    
    void send_out(){
        tcpHeader sendPackageTCP;
        pack sendIPpackage;
        uint8_t AW;
        sendTCPInfo *info = call SendQueue.head();

        socket_t socKey = info->socKey;
        uint8_t flag = info->flag;
        uint8_t seq = info->seq;
        uint8_t ack = info->ack; 
        pack* payload = &(info->payload);
        uint8_t length = info->length;

        socket_store_t * socketHolder = call Connections.getPointer(socKey);

        dbg(TRANSPORT_CHANNEL,"error_t send_out Called\n");
        dbg(TRANSPORT_CHANNEL,"\tsocketHolder->state %d\n", socketHolder->state);
        dbg(TRANSPORT_CHANNEL,"\tsocKey %d\n", info->socKey);


        switch (socketHolder->state)
            { 
            case CLOSED: 
                dbg(TRANSPORT_CHANNEL,"error:  connection does not exist\n");
                return;
                break;  
            case SYN_RCVD: case ESTABLISHED: case FIN_WAIT_1: case FIN_WAIT_2: case CLOSE_WAIT:
            if(length == 0){
                //AW = updateRecieverSlideWindow(socKey, &sendPackageTCP);
                AW = 5;
            }
            else{
                AW = 5;
            }
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
        sendPackageTCP.Advertised_Window = AW;
        memcpy(sendPackageTCP.payload, payload, length);
        /*END OF: Make the TCP Packet*/
        makeIPpack(&sendIPpackage, &sendPackageTCP, socketHolder, length + TCP_HEADER_LENGTH); //maybe reduce the PACKET_MAX_PAYLOAD_SIZE
        ipSeq = ipSeq + 1;

        dbg(TRANSPORT_CHANNEL,"\tlength %d\n", length);
        dbg(TRANSPORT_CHANNEL,"sendPackageTCP.Len %d\n", sendPackageTCP.Len);
       // dbg(TRANSPORT_CHANNEL,"(sendIPpackage.package).Len %d\n", (sendIPpackage.payload).Len);


        call Sender.send(sendIPpackage, call DistanceVectorRouting.GetNextHop(socketHolder->dest.addr));

        //update socket -------------------------------------------
        socketHolder->lastSent = sendPackageTCP.Seq_Num;

        // if (socketHolder->lastSent == 0) {socketHolder->nextExpected = 0;}
        // else{socketHolder->nextExpected = 1;}    

        //save a copy of the packet to be re-sent by a timmer and set RTT & TTD lastTimeSent
        //socketHolder->RTT = (socketHolder->lastTimeRecived - socketHolder->lastTimeSent) + call LocalTime.get() + 300;
        //socketHolder->TTD = (socketHolder->RTT) * 3;
        call SendQueue.dequeue();
        call SendPool.put(info);

    }

    //should return the ammount of data written to the socket
    error_t send_buff(socket_t socKey, uint8_t flag, uint8_t seq, uint8_t ack, uint8_t* payload, uint8_t length){
        //put packets in a que 
        socket_store_t * socketHolder = call Connections.getPointer(socKey);
        dbg(TRANSPORT_CHANNEL,"Called send_buff()\n");

        dbg(TRANSPORT_CHANNEL,"\tsocKey %d\n", socKey);
        dbg(TRANSPORT_CHANNEL,"\tsocketHolder->state %d\n", socketHolder->state);
        dbg(TRANSPORT_CHANNEL,"\tlength %d\n", length);

        if(!call SendPool.empty()){
            sendTCPInfo *input = call SendPool.get();
            input->socKey = socKey;
            input->flag = flag;
            input->seq = seq;
            input->ack = ack;
            memcpy(&(input->payload), payload, length);
            input->length = length;
            
            dbg(TRANSPORT_CHANNEL,"input->length %d\n", input->length);


            // Now that we have a value from the pool we can put it into our queue.
            // This is a FIFO queue.
            call SendQueue.enqueue(input);
            //call ReSendBuff.insert(info)

            // Start a send task which will be delayed.
             send_out();

            return SUCCESS;
        }
        return FAIL;
    }

    task void TimerTask(){
        //check for TIME_WAIT to close wait for 2 times msl
        //time out connection
        //packet resender / data sender
        //normal sender
      
        uint16_t i;
        uint8_t j; 
        sendTCPInfo* TCPinfo; // has socket_t, flag, payload, length
        socket_store_t * mySocket;
        socket_store_t * resendSocket;
        socket_store_t * sendSocket;
        uint8_t size = call Connections.size();
        uint32_t * keys = call Connections.getKeys();

        if (call Connections.isEmpty() == TRUE) return; //if there are no connections don't do anything.
        for (i = 0; i < size ; i++)
        {
            mySocket = call Connections.getPointer(keys[i]);
           // dbg(TRANSPORT_CHANNEL,"mySocket->state %d\n", mySocket->TTD);
            //dbg(TRANSPORT_CHANNEL,"call LocalTime.get() %d | mySocket->TTD %d\n", call LocalTime.get(), mySocket->TTD);

            if(mySocket->state == TIME_WAIT && mySocket->TTD < call LocalTime.get())
            {
                mySocket->state = CLOSED;
                dbg(TRANSPORT_CHANNEL, "STATE: TIME_WAIT -> CLOSED\n");
                call Connections.remove(i);

            }
            /* if (mySocket->TTD < call LocalTime.get())
            {
                call Transport.close(i);
            }
            */


            //TO_DO: implement resender
            
               /* Else if ( if there is new data that needs to be sent)//no packets should be in flight
                If the sockets state == FIN_WAIT_1
                    Add a FIN to the ACK flag for the sending of data
                Send it according to the sliding window*/

            if(mySocket->lastSent > mySocket->lastAck){ //if there is data in flight
                //fill later  fill with resend stuff
            }
            else if(mySocket->lastWritten >= mySocket->lastSent){  //of there is data to be sent
                uint8_t buffSize; // is already declared in line 202
                uint8_t dataBuffer[SOCKET_BUFFER_SIZE];
                uint8_t sendDataHolder = 0;
                for (i = 0; i < SOCKET_BUFFER_SIZE; i++)
			        dataBuffer[i] = '\0';
                switch(mySocket->state){
                    case ESTABLISHED: case CLOSE_WAIT:
                        dbg(TRANSPORT_CHANNEL,"mySocket->lastWritten %d | mySocket->lastSent %d\n", mySocket->lastWritten, mySocket->lastSent);


                        //figure out amount of data to send

                        //dbg(TRANSPORT_CHANNEL, "Message in Socket is %s\n", mySocket->sendBuff);


                        for(buffSize=0; mySocket->sendBuff[buffSize] != '\0'; buffSize++){} 
                        //dbg(TRANSPORT_CHANNEL, "buffSize %d\n", buffSize);
                        buffSize = buffSize - mySocket->lastAck +1;
                        dbg(TRANSPORT_CHANNEL, "buffSize %d\n", buffSize);

                        if(mySocket->effectiveWindow >= buffSize){
                            //keep buffSize the same
                        }
                        else{
                            buffSize = mySocket->effectiveWindow;
                            dbg(TRANSPORT_CHANNEL, "form effectiveWindow buffSize %d\n", buffSize);
                        }

                        //dbg(TRANSPORT_CHANNEL, "buffSize %d\n", buffSize);

                        
                        while(buffSize > 0){
                            if (TCP_PACKET_MAX_PAYLOAD_SIZE > buffSize){
                                memcpy(dataBuffer, &(mySocket->sendBuff)[sendDataHolder + mySocket->lastAck - 1], buffSize);
                                dbg(TRANSPORT_CHANNEL, "buffSize %d\n", buffSize);
                                dbg(TRANSPORT_CHANNEL, "Message to send is:%s\n", dataBuffer);
                                dbg(TRANSPORT_CHANNEL, "mySocket->lastRcvd + 1 %d\n",mySocket->lastRcvd + 1);
                                send_buff(mySocket->src, ACK, mySocket->lastAck + buffSize, mySocket->lastRcvd + 1 , dataBuffer, buffSize);
                                buffSize = 0;
                            }
                            else{
                                memcpy(dataBuffer, &(mySocket->sendBuff)[sendDataHolder + mySocket->lastAck - 1], TCP_PACKET_MAX_PAYLOAD_SIZE);
                                dbg(TRANSPORT_CHANNEL, "Message to send is:%s\n", dataBuffer);
                                send_buff(mySocket->src, ACK, mySocket->lastAck + TCP_PACKET_MAX_PAYLOAD_SIZE, mySocket->lastRcvd + 1 , dataBuffer, TCP_PACKET_MAX_PAYLOAD_SIZE);
                                dbg(TRANSPORT_CHANNEL, "mySocket->lastRcvd + 1 %d\n", mySocket->lastRcvd + 1);
                                buffSize = buffSize - TCP_PACKET_MAX_PAYLOAD_SIZE;
                                sendDataHolder = sendDataHolder + TCP_PACKET_MAX_PAYLOAD_SIZE;
                            }
                        }
                        break;
                    default:
                        break;
                }
                return;
            }

            /*
            if there is/are packets to be resent for this socket
                For each of the resend packets for this socket 
                        if(the RTT < current time)
                        Send it/them
                        Update their RTT and put them back in the resend que
            Else if ( if there is new data that needs to be sent)//no packets should be in flight
                If the sockets state == FIN_WAIT_1
                    Add a FIN to the ACK flag for the sending of data
                Send it according to the sliding window
            Else if (there is a packet/packets in the send buffer that needs to be sent from this socket //normal sender
                If the sockets state == FIN_WAIT_1
                    Send a fin pack
                If the sockets state == CLOSE_WAIT
                    call Transport.close(curConection->src);
                Send the first packet and move it to the resend que
            */

            // if (call ReSendQueue.empty() == FALSE) //  how do i check for the specific socket?
            // {
            //     for (j = 0; j < call ReSendQueue.size(); j++)
            //     {
            //         TCPinfo = call ReSendQueue.element(j);
                   
            //         resendSocket = call Connections.getPointer(TCPinfo->socKey);
                   
            //        if (resendSocket->RTT < call LocalTime.get())
            //        {
            //          //send packet
            //          //update RTT and put them back in the resend queue

            //        }
            //     }
            // }
            // else if (call SendQueue.empty() == FALSE)
            // {
            //     //send data through sliding window sender type
            //     //checking effective window
            //     for (j = 0; j < call ReSendQueue.size(); j++)
            //     {
            //         TCPinfo = call SendQueue.element(j);
                   
            //         sendSocket = call Connections.getPointer(TCPinfo->socKey);
                   

            //        //sendSocket->effectiveWindow
            //        //think about it 

            //     }
            //}
            /*
            Else if (there is a packet/packets in the send buffer that needs to be sent from this socket //normal sender
            Send the first packet and move it to the resend que
            */
            // if(mySocket->state == FIN_WAIT_1){
            //     send_buff(mySocket->src, FIN, mySocket->lastAck+1, lastRcvd+1, Empty, 0)
            // }

        }
    }

    event void Timer.fired(){
        post TimerTask();
        //return SUCCESS;
    }

    command socket_t Transport.socket(socket_t fd){
        dbg(TRANSPORT_CHANNEL,"Transport.socket() Called\n");
        if(!(call Timer.isRunning())){call Timer.startPeriodic(512);} //Start Timer
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
        uint8_t i;

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
        TCB.effectiveWindow = 5;  //NOTE:We Need to replace this value
        TCB.TTD = 0;
        for (i = 0; i < SOCKET_BUFFER_SIZE; i++) {
			TCB.sendBuff[i] = '\0';
			TCB.rcvdBuff[i] = '\0';
		}
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

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){ //NOTE: FIGURE out how to deal with writing if the buffer is not full but past its max seq #
        socket_store_t * socketHolder ;
        uint8_t written;
        dbg(TRANSPORT_CHANNEL,"Transport.write() Called\n");

        if (!(call Connections.contains(fd))) return 0;
        socketHolder = call Connections.getPointer(fd);
        if (buff == NULL || bufflen < 1) return 0;

        switch (socketHolder->state)
        { 
        case CLOSED: 
            dbg(TRANSPORT_CHANNEL,"error:  connection does not exist\n");
            break;  
        case LISTEN:
        case SYN_SENT:
        case SYN_RCVD:
        case ESTABLISHED: // right here, writes to the send buffer
        case CLOSE_WAIT:
            //get size of buffer
            //for(written=0; socketHolder->sendBuff[written] == '\0'; written++){} 

            dbg(TRANSPORT_CHANNEL, "\t\tbufflen = %d\n", bufflen);
            if (bufflen > SOCKET_BUFFER_SIZE){
               written = SOCKET_BUFFER_SIZE;
            }
            else{
                written = bufflen;
            }

            socketHolder->lastWritten = written;
            
            // if (bufflen > written){
            //    // will write the max ammount
            // }
            // else{
            //     written = bufflen;
            // }
            memcpy((socketHolder->sendBuff), buff, written);
            dbg(TRANSPORT_CHANNEL, "Message written to sendBuff is %s\n", socketHolder->sendBuff);

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

        dbg(TRANSPORT_CHANNEL, "INCOMING SEQ #: %d INCOMING ACK #: %d\n",mySegment->Seq_Num,mySegment->Acknowledgment);

        // //TO_DO: add check here to see if the packet has been seen before
                //this means the sent packet was lost resend it again and extend the close time


        curConection->lastRcvd = mySegment->Seq_Num;
        //curConection->LastRecivedIPpack = *myMsg;

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
                uint8_t ISN = 100;
                call Transport.accept(curConection->src, myMsg);
                seq = mySegment->Seq_Num;
                send_buff(curConection->src, SYN+ACK, ISN, seq + 1, Empty, 0);
                curConection->nextExpected = ISN + 1; //Replace this
                curConection->state = SYN_RCVD;
                dbg(TRANSPORT_CHANNEL, "STATE: LISTEN -> SYN_RCVD\n");

                return SUCCESS;
            }
            else{ //Wrong info
                return SUCCESS;
            }
            break; 
            case SYN_SENT:
            if(mySegment->Flags & ( SYN | ACK )) {
                //any segments on the retransmission queue which are thereby acknowledged should be removed.
                if(curConection->lastSent + 1 == mySegment->Acknowledgment){
                    dbg(TRANSPORT_CHANNEL, "STATE: SYN_SENT -> ESTABLISHED\n");

                    // if(curConection->lastSent == 0){seq = 1;}
                    // else{seq = 0;}

                    //seq = mySegment->Acknowledgment;

                    //send_buff(curConection->src, ACK, seq, mySegment->Seq_Num + 1, Empty, 0);
                    curConection->lastAck = mySegment->Acknowledgment - 1;
                    // curConection->nextExpected = seq + 1;
                    curConection->state = ESTABLISHED;
                    return SUCCESS;
                }

                //TO_DO:call event to start sending packets from que.
            }
            else return SUCCESS;
            break; 

            ///new bits
        }

        if(mySegment->Acknowledgment <= curConection->lastSent /*&& mySegment->Len == 0*/){
            dbg(TRANSPORT_CHANNEL, "mySegment->Acknowledgment %d <= curConection->lastSent %d\n", mySegment->Acknowledgment, curConection->lastSent);
            //resend the stuff
            return SUCCESS;
        }

        //check sequence number HERE
        if(curConection->nextExpected <= mySegment->Seq_Num && mySegment->Len > 0){
            dbg(TRANSPORT_CHANNEL, "curConection->nextExpected %d  mySegment->Seq_Num %d\n", curConection->nextExpected, mySegment->Seq_Num);
            if(curConection->nextExpected < mySegment->Seq_Num){
                return FAIL; //should put it back in the buffer
            }
            dbg(TRANSPORT_CHANNEL, "Recived packet with unexpected SEQ #\n");
            return SUCCESS;
        }

        switch (curConection->state) {

            case SYN_RCVD:
                //put some checks here
                if(mySegment->Flags & ( SYN | ACK )) {
                    if(curConection->lastSent + 1 == mySegment->Acknowledgment){
                //any segments on the retransmission queue which are thereby acknowledged should be removed.

                        curConection->state = ESTABLISHED;
                        dbg(TRANSPORT_CHANNEL, "STATE: SYN_RCVD -> ESTABLISHED\n");

                        if(mySegment->Len > 0)
                            goto ESTAB;

                        seq = mySegment->Acknowledgment;
                        send_buff(curConection->src, ACK, seq, mySegment->Seq_Num + 1, Empty, 0);
                        curConection->nextExpected = seq + 1;
                        curConection->lastAck = mySegment->Acknowledgment- 1;


                        return SUCCESS;
                    }
                }
                else return SUCCESS;
                break;
            case LAST_ACK:
                if(mySegment->Flags == ACK){
                    if(curConection->nextExpected == mySegment->Acknowledgment){
                        curConection->state=CLOSED;
                        dbg(TRANSPORT_CHANNEL, "STATE: LAST_ACK -> CLOSED\n");
                        call Connections.remove(curConection->src);
                    }
                    else{
                        //do somthing 
                    }
                    return SUCCESS;
                    break;
                }             
            case FIN_WAIT_1:
                if(mySegment->Flags == ACK){
                    curConection->state = FIN_WAIT_2;
                    dbg(TRANSPORT_CHANNEL, "STATE: FIN_WAIT_1 -> FIN_WAIT_2\n");
                    return SUCCESS;
                }
            case FIN_WAIT_2:
                if(mySegment->Flags == ACK){
                    /*In addition to the processing for the ESTABLISHED
                  state, if the retransmission queue is empty, the
                  user's CLOSE can be acknowledged ("ok") but do not
                  delete the TCB.*/
                }   
                if(mySegment->Flags == FIN){
                    curConection-> state = TIME_WAIT;
                    dbg(TRANSPORT_CHANNEL, "STATE: FIN_WAIT_1 0r 2 -> TIME_WAIT\n");

                    seq = mySegment->Acknowledgment;
                    dbg(TRANSPORT_CHANNEL, "seq: %d ack: %d \n",seq,curConection->lastRcvd + 1);


                    send_buff(curConection->src, ACK, seq, curConection->lastRcvd + 1, Empty, 0); //update this
                    
                    curConection->lastAck = mySegment->Acknowledgment- 1;
                    dbg(TRANSPORT_CHANNEL, "curConection->lastSent: %d\n",curConection->lastSent);

                    //curConection->nextExpected;

                //set a timer that eventually closes the socket
                return SUCCESS;
                break;
                }
            case CLOSE_WAIT:
            case ESTABLISHED: //NOTE: everything below should be updated
                ESTAB:
                if(mySegment->Flags & FIN){
                    curConection-> state = CLOSE_WAIT;
                    dbg(TRANSPORT_CHANNEL, "STATE: ESTABLISHED -> CLOSE_WAIT\n");

                    //if(mySegment->Len == 0 && //if there is data in the reciver buffer && th){ //this is needed for server to close
                        //update socket
                        curConection->lastAck = mySegment->Acknowledgment - 1;

                        updateSenderSlideWindow(curConection->src, mySegment, 0);
                        call Transport.close(curConection->src);
                        return SUCCESS;
                    //timer? or command most likey command
                }
                if(mySegment->Flags & ACK){
                    if(mySegment->Acknowledgment <= curConection->lastAck){//ACK is a duplicate
                        dbg(TRANSPORT_CHANNEL, "Ack is a duplicate\n");
                        //it can be ignored
                        return SUCCESS;
                    }
                    if(mySegment->Acknowledgment > curConection->lastSent + 1){//ACK acks something not yet sent
                        //then send an ACK, drop the segment, and return.
                        dbg(TRANSPORT_CHANNEL, "mySegment->Acknowledgment %d > curConection->lastSent + 1 %d\n",mySegment->Acknowledgment,curConection->lastSent + 1);
                        dbg(TRANSPORT_CHANNEL, "recived Ack for something not yet sent\n");

                        return SUCCESS;
                    }
                    if(curConection->lastAck < mySegment->Acknowledgment && mySegment->Acknowledgment <= curConection->lastSent + 1){
                        curConection->lastAck = mySegment->Acknowledgment - 1;
                        //Any segments on the retransmission queue that are thereby entirely acknowledged are removed.
                    }

                    /*If SND.UNA =< SEG.ACK =< SND.NXT, the send window
                  should be updated.  If (SND.WL1 < SEG.SEQ or (SND.WL1
                  = SEG.SEQ and SND.WL2 =< SEG.ACK)), set SND.WND <-
                  SEG.WND, set SND.WL1 <- SEG.SEQ, and set SND.WL2 <-
                  SEG.ACK.*/
                    dbg(TRANSPORT_CHANNEL, "mySegment->Len %d\n",mySegment->Len);
                    if(mySegment->Len == 0){ //this is a normal ack pack
                        //update socket
                        updateSenderSlideWindow(curConection->src, mySegment, 0);
                        //send_buff(curConection->src, ACK, curConection->lastSent +1, curConection->lastRcvd + 1, Empty, 0); //update this

                        //stop resend for data
                       // updateSenderSlideWindow(curConection->src, mySegment, 0);

                    }
                    else{ // has data   //Only need to ipmlement this if you send more than one packet of data       
                        //update socket
                        
                        dbg(TRANSPORT_CHANNEL, "Message Recived:%s\n",mySegment->payload);
                       
                        readDataToBuff(curConection->src, mySegment, mySegment->Len); //returns amount put into buffer

                        seq = curConection->lastAck + 1;
                        send_buff(curConection->src, ACK, curConection->lastAck + 1, curConection->lastRcvd + 1, Empty, 0); //update this
                        curConection->nextExpected = seq + 1;
                    }
                }
                if(mySegment->Flags & PUSH){
                    dbg(TRANSPORT_CHANNEL, "Message Recived:%s\n",mySegment->payload);
                    dbg(TRANSPORT_CHANNEL, "\tFinished reciving Message\n");
                    dbg(TRANSPORT_CHANNEL, "\t\tMessage:%s\n",curConection->rcvdBuff);
                    //call Transport.read(curConection->src)
                    return SUCCESS;
                }
                else if(mySegment->Flags == RESET){}
                else if(mySegment->Flags == URG){}
                else return SUCCESS;
                break; 
            case TIME_WAIT:
                if(mySegment->Flags == URG){}
                if(mySegment->Flags == ACK){}
                if(mySegment->Flags == PUSH){}
                if(mySegment->Flags == RESET){}
                if(mySegment->Flags == SYN){}
                if(mySegment->Flags == FIN){
                    //this means the sent packet was lost resend it again and extend the close time
                    //should be taken care of earlyer
                }
                break; 

            default:
                dbg(TRANSPORT_CHANNEL, "FLAG_ERROR: \"%d\" does not match any known commands.\n", mySegment->Flags);
                return SUCCESS;
                break;
        }
        return SUCCESS;
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

    uint16_t readDataToBuff(socket_t fd, tcpHeader *tcpSegment, uint16_t bufflen){
        uint8_t buffSize;
        socket_store_t * socketHolder =  call Connections.getPointer(fd);
        uint8_t *buff = tcpSegment->payload;

        dbg(TRANSPORT_CHANNEL, "Transport Called readDataToBuff\n");

        for(buffSize=0; socketHolder->rcvdBuff[buffSize] != '\0'; buffSize++ ){} //calculates the size of the buffer
        if (bufflen > buffSize){
            // will write the max ammount
        }
        else{
            buffSize = bufflen;
        }

        strcat((socketHolder->rcvdBuff), buff);

        return buffSize;
    }
        
    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen){
        uint8_t buffSize, has_read;
        socket_store_t * socketHolder;
        
        uint8_t *socketBuff = socketHolder->rcvdBuff; //recheck with nathan
        dbg(TRANSPORT_CHANNEL, "Transport Called Read\n");

        if (!(call Connections.contains(fd))) return 0;
        socketHolder = call Connections.getPointer(fd);

        if (socketBuff == NULL || bufflen < 1) return 0;

        for(buffSize=0; socketHolder->rcvdBuff[buffSize] != '\0'; buffSize++ ){} //calculates the size of the buffer
        

        switch (socketHolder->state)
        { 
        case CLOSED: 
            dbg(TRANSPORT_CHANNEL,"error:  connection does not exist\n");
            break;  
        case FIN_WAIT_1:
        case FIN_WAIT_2:
        case TIME_WAIT:
        case CLOSING:
        case ESTABLISHED: // right here, writes to the send buffer
        case CLOSE_WAIT:

        //if there is not enuph data to put in the buffer Queue for later
            //insead return dbg ("not enough data has been recived")

            dbg(TRANSPORT_CHANNEL, "\t\tbufflen = %d\n", bufflen);
            if (bufflen > SOCKET_BUFFER_SIZE ){
               has_read = SOCKET_BUFFER_SIZE;
            }
            else{
                has_read = bufflen;
            }

            socketHolder->lastRead = has_read;
            
            // if (bufflen > written){
            //    // will write the max ammount
            // }
            // else{
            //     written = bufflen;
            // }
            memcpy(buff, socketHolder->rcvdBuff, has_read);
            dbg(TRANSPORT_CHANNEL, "Message written to sendBuff is %s\n", socketHolder->sendBuff); //fix

            //call sendDataTimer.startPeriodic(81000); //could be set to a diffrent number
            return has_read;
        case LISTEN:
        case SYN_SENT:
        case LAST_ACK:
        case SYN_RCVD:
            dbg(TRANSPORT_CHANNEL,"error: connection hasn't been opened\n");
            break;
        default:
            dbg(TRANSPORT_CHANNEL, "WRONG_STATE_ERROR: \"%d\" is an incompatable state or does not match any known states.\n", socketHolder->state);
            break;
        }
        return 0;
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr){
        socket_store_t * socketHolder ;
        uint8_t inSeq = 1; //choose inital sequence number
        dbg(TRANSPORT_CHANNEL, "connect() was called\n");
        if (!(call Connections.contains(fd))) return FAIL;
        socketHolder = call Connections.getPointer(fd);
        switch (socketHolder->state)
        { 
        case CLOSED: 
            socketHolder->state = SYN_SENT; //Change the state of the socket
            dbg(TRANSPORT_CHANNEL, "STATE: CLOSED -> SYN_SENT %d\n",socketHolder->state );
            send_buff(fd, SYN, inSeq, 1, Empty, 0); //ack,payload, len packet,  //make and send a packet //send buffer
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
            case SYN_RCVD:
                /*If no SENDs have been issued and there is no pending data to
                send, then form a FIN segment and send it, and enter FIN-WAIT-1
                state; otherwise queue for processing after entering
                ESTABLISHED state.*/

            case ESTABLISHED: //Starts the close
                mySocket->state = FIN_WAIT_1;
                send_buff(mySocket->src, FIN, mySocket->lastAck+1, mySocket->lastRcvd+1, Empty, 0);
                
                return SUCCESS;
                break;
            case FIN_WAIT_1: case FIN_WAIT_2:
                /*Strictly speaking, this is an error and should receive a
                "error: connection closing" response.  An "ok" response would
                be acceptable, too, as long as a second FIN is not emitted (the
                first FIN may be retransmitted though).*/

            //make timer that checks if the packets of the payload are done sending, wait APP, research to know when it's done, timer or a command
            case CLOSE_WAIT: //changes wait to FIN WAIT 2 flag fin
            //sudo Code:
                //Set state
                //Send packet
                //Set timmer
                //Queue this request until all preceding SENDs have been segmentized; then send a FIN segment, enter LAST-ACK state.
                seq = mySocket->lastSent + 1;

                send_buff(fd, FIN, seq, mySocket->lastRcvd + 1, Empty, 0); //update this
                mySocket->nextExpected = seq + 1;

                mySocket->state = LAST_ACK;

                return SUCCESS;
                break;
            case CLOSING: case LAST_ACK: case TIME_WAIT:
                dbg(TRANSPORT_CHANNEL, "error: connection closing\n");
                return FAIL;
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


    error_t updateSenderSlideWindow (socket_t fd, tcpHeader *tcpSegment, uint16_t bufflen)
    {
	    //lastSent is already updated here. but what about the other variables?
	    //??????????
	    socket_store_t * socketHolder ;
	    uint8_t *buff = tcpSegment->payload;

        if (!(call Connections.contains(fd))) return FAIL;
        socketHolder = call Connections.getPointer(fd);

        /*
	    if (socketHolder->flag == ACK && socketHolder->lastAck != socketHolder->lastRcvd )
	    {
	    socketHolder -> lastAck = socketHolder->lastRcvd; //maybe change this to socketHolder->lastRcvd;????
	
	    }
       */ 

	    if ((socketHolder->lastSent - socketHolder->lastAck) <= tcpSegment->Advertised_Window) //lecture 13 slide 58, advertised window from reciever;
	    {
		    if (socketHolder->lastAck <= socketHolder->lastSent && socketHolder->lastSent <= socketHolder->lastWritten) // lecture 13 slide 55
		    {
			    //effective window: how much new data it is OK for sender to currently send
			    socketHolder->effectiveWindow = tcpSegment->Advertised_Window - (socketHolder->lastSent - socketHolder->lastAck);
				dbg(TRANSPORT_CHANNEL, "effective window updating: %d\n", socketHolder->effectiveWindow);
                return SUCCESS;
		    }   
		
	
    	}
        return SUCCESS;

    }



    //call in timer before send
    uint8_t updateRecieverSlideWindow (socket_t fd, tcpHeader *tcpSegment)
    {
	//lastSent is already updated here. but what about the other variables
	//this happens after read

	    uint8_t *buff = tcpSegment->payload;
        socket_store_t * socketHolder;
	    if (!(call Connections.contains(fd))) return 0;
        socketHolder = call Connections.getPointer(fd);


	    if ((socketHolder->lastRcvd - socketHolder->lastRead) <= SOCKET_BUFFER_SIZE)
	    {
            dbg(TRANSPORT_CHANNEL, "socketHolder->lastRcvd - socketHolder->lastRead %d <= SOCKET_BUFFER_SIZE %d", socketHolder->lastRcvd - socketHolder->lastRead, SOCKET_BUFFER_SIZE);
		    if (socketHolder->lastRead < socketHolder->nextExpected)
		    {
                //dbg(TRANSPORT_CHANNEL, "socketHolder->lastRcvd - socketHolder->lastRead%d"
			    if (socketHolder->nextExpected <= socketHolder->lastRcvd + 1)
			    {
				    tcpSegment->Advertised_Window = SOCKET_BUFFER_SIZE - ((socketHolder->nextExpected - 1) - socketHolder->lastRead);
                    dbg(TRANSPORT_CHANNEL, "Advertised Window updated, it's now %d \n", tcpSegment->Advertised_Window);
				    return tcpSegment->Advertised_Window;

			    }
		    }
	    }	
    	return 0;
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
