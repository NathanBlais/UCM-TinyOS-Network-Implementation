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
}

implementation{
   pack sendPackage;
   am_addr_t nodes[10];
   uint16_t SEQ_NUM=1;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t *payload, uint8_t length);

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

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      pack *contents;
      if(len!=sizeof(pack)){
         dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
         return msg;
      }
      contents = (pack *)payload;
		if (contents->TTL == 0) //Kill the packet if TTL is 0
         return msg;
      contents-> TTL = (contents->TTL) - 1; //Reduce TTL

      if(contents->dest == AM_BROADCAST_ADDR) { 
         call Flooder.send(*contents, contents->dest);
      }
      if (contents->dest != TOS_NODE_ID){ //Check if the packet is not meant for the current node
			dbg(GENERAL_CHANNEL, "We're in Node %d \n \t\tRouting Packet- src:%d, dest %d, seq: %d, nexthop: %d, count: %d\n \n",TOS_NODE_ID, contents->src, contents->dest, contents->seq, call DistanceVectorRouting.GetNextHop(contents->dest), call DistanceVectorRouting.GetCost(contents->dest));
	      if (contents->protocol == PROTOCOL_PING || contents->protocol == PROTOCOL_PINGREPLY || contents->protocol == PROTOCOL_TCP)
            call Sender.send(*contents, call DistanceVectorRouting.GetNextHop(contents->dest));
         else
            dbg(GENERAL_CHANNEL, "Recived packet with incorrect Protocol?\n");
         return msg;
      } //End of the destination check. Packets should be ment for this node past this point
      
		//Check the Protocol 
		if (PROTOCOL_PING == contents->protocol) {
			dbg(GENERAL_CHANNEL, "Ping Message Recived:%s\n", contents->payload);
			makePack(&sendPackage, TOS_NODE_ID, contents->src, MAX_TTL, contents->seq, PROTOCOL_PINGREPLY, (uint8_t *)contents->payload, PACKET_MAX_PAYLOAD_SIZE);
			dbg(GENERAL_CHANNEL, "Sending Ping Reply to %d\n \n", contents->src);
			call Sender.send(sendPackage, call DistanceVectorRouting.GetNextHop(contents->src));
		}
	   else if (PROTOCOL_PINGREPLY == contents->protocol)
			dbg(GENERAL_CHANNEL, "Package Payload: %s\n", contents->payload);
      //else if (PROTOCOL_TCP == contents->protocol)
         //call Transport.receive(contents);
		else
			dbg(GENERAL_CHANNEL, "Recived packet with incorrect Protocol\n");

      //dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
      return msg;
      }

   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, SEQ_NUM, PROTOCOL_PING, payload, PACKET_MAX_PAYLOAD_SIZE);
      dbg(GENERAL_CHANNEL, "We're in Node: %d \n \t\tRouting Packet- src:%d, dest %d, seq: %d, nexthop: %d, count: %d\n \n", TOS_NODE_ID,TOS_NODE_ID, destination, SEQ_NUM, call DistanceVectorRouting.GetNextHop(destination), call DistanceVectorRouting.GetCost(destination));
      SEQ_NUM++;
      //call Sender.send(sendPackage, destination);
      //call Flooder.send(sendPackage, destination);
      call Sender.send(sendPackage, call DistanceVectorRouting.GetNextHop(destination));
   }
   
   event void CommandHandler.printNeighbors(){call NeighborDiscovery.print();}

   event void CommandHandler.printRouteTable(){call DistanceVectorRouting.print();}

   event void CommandHandler.printLinkState(){} //not used

   event void CommandHandler.printDistanceVector(){} //didn't know what to do with it

   event void CommandHandler.setTestServer(uint8_t port){
      socket_addr_t myAddr; //not realy needed exept to satisfy bind requirements
      socket_t mySocket = call Transport.socket();

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

   event void CommandHandler.setTestClient(){}

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
