/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;
   uses interface Flooder;

   uses interface CommandHandler;

   uses interface NeighborDiscovery;
   uses interface DistanceVectorRouting;
   uses interface Transport;

   uses interface Queue<reciveInfo*>;
   uses interface Pool<reciveInfo>;
}

implementation{
   pack sendPackage;
   am_addr_t nodes[10];
   uint16_t SEQ_NUM=1;
   char toSend[] = {'A','B','C','D','E','F','G','H','I',
      'J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'};

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t *payload, uint8_t length);
   error_t receive(message_t* msg, pack* payload, uint8_t len);


   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted before debugging \n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
      call NeighborDiscovery.run();
      call DistanceVectorRouting.run();
   }

   event void AMControl.stopDone(error_t err){}

   task void receiveBufferTask(){
       // If we have a values in our queue and the radio is not busy, then
       // attempt to send a packet.
        if(!call Queue.empty()){
         reciveInfo *info;
         // We are peeking since, there is a possibility that the value will not
         // be successfuly sent and we would like to continue to attempt to send
         // it until we are successful. There is no limit on how many attempts
         // can be made.
         info = call Queue.head();

         // Attempt to send it.
            if(SUCCESS == receive(&(info->msg),&(info->payload), info->len)){
                //Release resources used if the attempt was successful
                call Queue.dequeue();
                call Pool.put(info);
            }
        }
   }

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
        if(!call Pool.empty()){
            reciveInfo *input;

            input = call Pool.get();
            memcpy(&(input->msg), msg, sizeof(*msg));
            memcpy(&(input->payload), payload, PACKET_MAX_PAYLOAD_SIZE);
            input->len = len;

            // Now that we have a value from the pool we can put it into our queue.
            // This is a FIFO queue.
            call Queue.enqueue(input);

            // Start a send task which will be delayed.
            post receiveBufferTask();

            return msg;
        }
        return msg;
    }

   error_t receive(message_t* msg, pack* payload, uint8_t len){
      pack *contents;
      error_t result; //for debug
      if(len!=sizeof(pack)){
         dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
         return SUCCESS;
      }
      contents = payload;
		if (contents->TTL == 0) //Kill the packet if TTL is 0
         return SUCCESS;
      contents-> TTL = (contents->TTL) - 1; //Reduce TTL

      if(contents->dest == AM_BROADCAST_ADDR) { 
         call Flooder.send(*contents, contents->dest);
      }
      if (contents->dest != TOS_NODE_ID){ //Check if the packet is not meant for the current node
			dbg(GENERAL_CHANNEL, "\t\tRouting Packet- src:%d, dest %d, seq: %d, nexthop: %d, count: %d\n",TOS_NODE_ID, contents->src, contents->dest, contents->seq, call DistanceVectorRouting.GetNextHop(contents->dest), call DistanceVectorRouting.GetCost(contents->dest));
	      if (contents->protocol == PROTOCOL_PING || contents->protocol == PROTOCOL_PINGREPLY || contents->protocol == PROTOCOL_TCP)
            result = call Sender.send(*contents, call DistanceVectorRouting.GetNextHop(contents->dest));
         else
            dbg(GENERAL_CHANNEL, "Recived packet with incorrect Protocol?\n");
         return SUCCESS;
      } //End of the destination check. Packets should be ment for this node past this point
      
		//Check the Protocol 
		if (PROTOCOL_PING == contents->protocol) {
			dbg(GENERAL_CHANNEL, "Ping Message Recived:%s\n", contents->payload);
			makePack(&sendPackage, TOS_NODE_ID, contents->src, MAX_TTL, contents->seq, PROTOCOL_PINGREPLY, (uint8_t *)contents->payload, PACKET_MAX_PAYLOAD_SIZE);
			dbg(GENERAL_CHANNEL, "Sending Ping Reply to %d\n \n", contents->src);
			result = call Sender.send(sendPackage, call DistanceVectorRouting.GetNextHop(contents->src));
         dbg(GENERAL_CHANNEL, "RECIVE EVENT SEND result: %d \n",result);
		}
	   else if (PROTOCOL_PINGREPLY == contents->protocol)
			dbg(GENERAL_CHANNEL, "Package Payload: %s\n", contents->payload);
      else if (PROTOCOL_TCP == contents->protocol)
      {
         call Transport.receiveBuffer(contents);
      }
		else
			dbg(GENERAL_CHANNEL, "Recived packet with incorrect Protocol\n");

      //dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
      return SUCCESS;
      }

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      error_t result;
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      dbg(GENERAL_CHANNEL, "Sucsess: %d | FAIL: %d \n",SUCCESS, FAIL);
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, SEQ_NUM, PROTOCOL_PING, payload, PACKET_MAX_PAYLOAD_SIZE);
      dbg(GENERAL_CHANNEL, "We're in Node: %d \n \t\tRouting Packet- src:%d, dest %d, seq: %d, nexthop: %d, count: %d\n \n", TOS_NODE_ID,TOS_NODE_ID, destination, SEQ_NUM, call DistanceVectorRouting.GetNextHop(destination), call DistanceVectorRouting.GetCost(destination));
      SEQ_NUM++;
      //call Sender.send(sendPackage, destination);
      //call Flooder.send(sendPackage, destination);
      result = call Sender.send(sendPackage, call DistanceVectorRouting.GetNextHop(destination));
      dbg(GENERAL_CHANNEL, "PING EVENT result: %d \n",result);
   }
   
   event void CommandHandler.printNeighbors(){call NeighborDiscovery.print();}

   event void CommandHandler.printRouteTable(){call DistanceVectorRouting.print();}

   event void CommandHandler.printLinkState(){} //not used

   event void CommandHandler.printDistanceVector(){} //didn't know what to do with it

   event void CommandHandler.setTestServer(uint8_t port){
      socket_addr_t myAddr; //not realy needed exept to satisfy bind requirements
      socket_t mySocket = call Transport.socket(port);

      if (mySocket == 0){
         dbg(TRANSPORT_CHANNEL, "Could not retrive an available socket\n");
         //return;
         }

      myAddr.addr = TOS_NODE_ID; //filled with usless info
      myAddr.port = mySocket;    //filled with usless info

      if(call Transport.bind(mySocket, &myAddr))
         return;

      if(call Transport.listen(mySocket))
         return;

      //Set off timer to close it after an amount of time
   }

   event void CommandHandler.setTestClient(uint8_t srcPort, uint8_t destination, uint8_t destPort, uint8_t *payload){
      socket_addr_t destAddr;
      uint8_t i;//, AmountWritten;
      socket_t mySocket = call Transport.socket(srcPort);
      destAddr.addr = destination; //filled with usless info
      destAddr.port = destPort;    //filled with usless info
      if(call Transport.bind(mySocket, &destAddr))
         return;
      for(i=0; payload[i] != '\0'; i++ ){}
      //call Transport.write(srcPort,payload,i);
      if(call Transport.connect(mySocket, &destAddr))
         return;
      //save the value here into a holder to read for bugtesting
      //for(i=0; payload[i] != '\0'; i++ ){}
      //dbg(TRANSPORT_CHANNEL, "sizeof(payload): %d\n", i);
      //dbg(TRANSPORT_CHANNEL, "payload: %s\n", payload);
      //AmountWritten = 
      call Transport.write(srcPort,payload,i);
      //call Transport.write(srcPort,toSend,26);


      //add the payload to a que to be cut up and packaged to be sent after connection

      //Set off timer to close or resend it after an amount of time
   }

   event void CommandHandler.cmdClientClose(uint8_t address, uint8_t srcPort, uint8_t destination, uint8_t destPort){
      call Transport.close(srcPort);
   }

   event void CommandHandler.cmdServerRead(uint8_t port, uint16_t  bufflen){
      char buff[SOCKET_BUFFER_SIZE];
      uint8_t i;
      for (i = 0; i < SOCKET_BUFFER_SIZE; i++) buff[i] = '\0';


      call Transport.read((socket_t)port, buff, bufflen);
      dbg(GENERAL_CHANNEL, "Message Read from Application layer:%s\n", buff);
   }


   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
