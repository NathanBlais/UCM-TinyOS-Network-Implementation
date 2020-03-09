//      Author:Nathan Blais
//Date Created:2020-02-16

#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module DistanceVectorRoutingP
{
    provides interface DistanceVectorRouting;

    //Uses the SimpleSend interface to forward recieved packet as broadcast
    uses interface SimpleSend as Sender;
    //Uses the Receive interface to determine if received packet is meant for me.
    uses interface Receive as Receiver;
    uses interface AMPacket;

    //Uses the NeighborDiscovery interface get current neighbor list and info.
    uses interface NeighborDiscovery;

    //Uses the periodicTimer to send packets at regular intervals
    uses interface Timer<TMilli> as InitalizationWait;
    uses interface Timer<TMilli> as advertiseTimer;

    uses interface Random; //Not really used anymore
    uses interface RouteTable;

    //interface PacketAcknowledgements <- i just found this
    //interface RouteSelect;
    //interface RouteControl as RouteSelectCntl;



//QUESTION:Do we want to use these?

    //Uses the Queue interface to determine if packet recieved has been seen before
    uses interface List<pack> as PacketsList;
    //NOTE:remember to store src & seq for each node
}

/* --------- Questions Area --------- *\
✱This is where we put our general questions
        ➤•⦿◆ →←↑↓↔︎↕︎↘︎⤵︎⤷⤴︎↳↖︎⤶↲↱⤻

    ➤ What should we store the routes in?
        •Should it be a diffrent formmat to the one we send?
    
    ➤ Is there a hard limmit the ammount of data we can send per packet?
        •Is there a way to increase it?
        •Do we have to find a way to split the size of the packet and reconstruct it?

    ➤

    ➤


\* --------- Questions Area --------- */


implementation
{
    // Globals
    pack sendPackage;
    uint16_t SEQ_NUM=1;

	//NOTE: istead of using a List to store KnownPackets, 
		  //we keep a simple array or hash to store the latest
		  //sequence number for each neighbor


	// Prototypes
    void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, route * payload, uint8_t length);
    void printRouteTable();
    void InitalizeRoutingTable();
    void updateRoutingTable(route * newRoutes, uint16_t size);

//--==Comands==--＼＼


    //Starts timer to send route values to our neighbors
    command void DistanceVectorRouting.run()
    {
        call InitalizationWait.startOneShot(1000);
        //call InitalizationWait.startPeriodic(30000 /*+ (call Random.rand16() %300)*/); //30 Seconds
        //call periodicTimer.startPeriodic(150000 /* 
      //  + (call Random.rand16() %300) */);
        //NOTE:we should tune the timming
    }

    //Is called by the CommandHandler to print the nodes Routing Table
    command void DistanceVectorRouting.print()
    {
        printRouteTable();
    }

    //
    command uint16_t DistanceVectorRouting.GetNextHop(uint16_t destination)
    {
        neighbor tempN = {destination, 0};
        route tempR = {tempN};
        uint16_t position = call RouteTable.getPosition(tempR);
        dbg(ROUTING_CHANNEL, "Getting Next Hop\n");
        
        if(position == MAX_ROUTES){
            dbg(ROUTING_CHANNEL, "The route is not known\n");
            return 0;
        }

        return(((call RouteTable.get(position)).NextHop).id);
    }

//--==Events==--＼＼

    event void InitalizationWait.fired()
    {
        InitalizeRoutingTable();
        call InitalizationWait.stop();
    }

    event void advertiseTimer.fired(){
        uint16_t h,i;
        uint16_t sizeR = call RouteTable.size();
        uint16_t sizeN = call NeighborDiscovery.getNeighborhoodSize();
        neighbor * neighborhood = call NeighborDiscovery.getNeighborsPointer();
        route * routes = call RouteTable.getPointer();
        route pak;

        dbg(ROUTING_CHANNEL, "Routing advertiseTimer fired\n");

        for(h=0; h < sizeR; h++){ //every destination in RoutingTable
            for(i=0; i < sizeN; i++){//every neighbor
                if(neighborhood[i].id != (routes[h].NextHop).id){
                        pak = routes[h];
                        makePack(&sendPackage, TOS_NODE_ID,
                                               neighborhood[i].id,
                                               1,
                                               1,//SEQ_NUM,
                                               PROTOCOL_DV,
                                               &pak, //NOTE:incompatabe type
                                               PACKET_MAX_PAYLOAD_SIZE);
                    call Sender.send(sendPackage,neighborhood[i].id);
                } 
                else{ //apply Split Horizon with Poison Reverse
                     pak = routes[h];
                     pak.Cost = MAX_COST;
                        makePack(&sendPackage, TOS_NODE_ID,
                                               neighborhood[i].id,
                                               1,
                                               1,//SEQ_NUM,
                                               PROTOCOL_DV,
                                               &pak, //NOTE:incompatabe type
                                               PACKET_MAX_PAYLOAD_SIZE);
                    call Sender.send(sendPackage,neighborhood[i].id);
                }
            }
        }
        call advertiseTimer.startOneShot(6000);
    }

    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len){
        dbg(ROUTING_CHANNEL, "Packet Received in DVRouter\n");
        //Check to see if the packet is the right size
        if(len==sizeof(pack)){
            pack* myMsg=(pack*) payload;
            route* routes = (route*) myMsg->payload;
            route* theTable = call RouteTable.getPointer();
            uint16_t cost = routes->Cost + 1;
            route forNewRoute;
            uint16_t position = call RouteTable.getPosition(*routes);

            //Check that the packet has the proper protocol
            if(myMsg->protocol != PROTOCOL_DV){
                dbg(ROUTING_CHANNEL, "Wrong Protocal Recived\n");
                return msg;}

            //Check that the route's "destination" is not the current node
            if((routes->Destination).id == TOS_NODE_ID){
                return msg;
            }
            //main RIP receiver
                    //if (dest ∈/ known) and (newMetric < 16) then
            if(position == MAX_ROUTES/* && cost < MAX_COST*/){ //New Route
                if (call RouteTable.size() >= MAX_ROUTES){
                    dbg(ROUTING_CHANNEL, "Routing Table Full\n");
                    return msg;}
                (forNewRoute.Destination).id = (routes->Destination).id;
                forNewRoute.Cost = cost; 
                (forNewRoute.NextHop).id = myMsg->src; 
                forNewRoute.TTL = 0; 

                call RouteTable.pushback(forNewRoute);
                //SET TO EXPIRE 
            }
            else{
                if((call RouteTable.get(position)).Cost > cost /*|| (call RouteTable.get(position)).Cost < MAX_COST*/)
                {
                    (theTable[position].Destination).id = (routes->Destination).id;
                    theTable[position].Cost = cost;
                    (theTable[position].NextHop).id = (routes->NextHop).id;
                   //theTable[position]->Destination.id = (routes->Destination).id;
                }
            }
        return msg;
       }
       dbg(ROUTING_CHANNEL, "Unknown Packet Type %d\n", len);
       return msg;
   }

//--==Funcions==--＼＼

    void InitalizeRoutingTable(){
        uint16_t i;
        neighbor * neighborhood = call NeighborDiscovery.getNeighborsPointer();
        uint16_t size = call NeighborDiscovery.getNeighborhoodSize(); //pointerArrayCounter(neighbors);
        route neighborRoute;
        //neighbor node = {TOS_NODE_ID, 0};

        for (i = 0; i < size; i++){
            //use a Temporary route to insert neighbor info into routing table
            neighborRoute.Destination = neighborhood[i];
            neighborRoute.NextHop = neighborhood[i];
            neighborRoute.Cost = 1; /* distance metric */ //temprarily for NumOfHops
            neighborRoute.TTL = 0;

            call RouteTable.pushback(neighborRoute);

        }
        call advertiseTimer.startPeriodic(10000); //30 Seconds
    }
 

    void printRouteTable()
    {
        uint16_t size = call RouteTable.size();
        uint8_t i;
        route node;

        dbg(GENERAL_CHANNEL, "Node %d | Size %d Route List:\n", TOS_NODE_ID, size);

        for (i = 0; i < size; i++)
        {
            node = call RouteTable.get(i);
            dbg(GENERAL_CHANNEL, "\t\tDestination: %d Cost: %d NextHop: %d TTL: %d\n", (node.Destination).id, node.Cost, (node.NextHop).id, node.TTL);
        }
    }
        
    void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, route * payload, uint8_t length)
    {
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }
    
}//for implementation