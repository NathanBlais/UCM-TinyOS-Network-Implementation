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

    uses interface Random;
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

    ➤ Should we create a custom dataStructure for our RoutingTable?
        ◆ This would give us more flexability and control
          at the cost of the time it takes to make it.

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



//QUESTION:What do we absolutly need?

//--==Comands==--＼＼

    //NOTE: Comands we need: 

        // • GetNextHop

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
        //call advertiseTimer.stop(); //stop timer to give time for prossessing


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
        //call advertiseTimer.startPeriodic(10000); //30 Seconds
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

            if((routes->Destination).id == TOS_NODE_ID){
                return msg;
            }
        
            //main RIP receiver
            
                    //if (dest ∈/ known) and (newMetric < 16) then
            if(position == MAX_ROUTES/* && cost < MAX_COST*/){ //New Route
                if (call RouteTable.size() >= MAX_ROUTES){
                    dbg(GENERAL_CHANNEL, "Routing Table Full\n");

                    return msg;}
                (forNewRoute.Destination).id = (routes->Destination).id;
                forNewRoute.Cost = cost; 
                (forNewRoute.NextHop).id = myMsg->src; 
                forNewRoute.TTL = 0; 

                call RouteTable.pushback(forNewRoute);
                //SET TO EXPIRE 
            }
            else{

                if(/*(call RouteTable.get(position)).Cost < MAX_COST ||*/ (call RouteTable.get(position)).Cost > cost)
                {

                    //call RouteTable.getPointer;
                   // (call RouteTable.get(position)).Destination.id = (routes->Destination).id;
                    //(call ROut)

                    (theTable[position].Destination).id = (routes->Destination).id;
                    theTable[position].Cost = cost;
                    (theTable[position].NextHop).id = (routes->NextHop).id;
                   // theTable[position]->Destination.id = (routes->Destination).id;


                }

            }


            //if ((routes->Destination).id != ((call RouteTable.get(i)).Destination).id)

 /*

    else
    {
        if (hopsdest < 16 and router = nextRouterdest ) or (newMetric < hopsdest ) 
        {
            hopsdest ← newMetric
            nextRouterdest ← router
            nextIfacedest ← iface

            if (newMetric = 16) then 
            {
                deactivate expiredest
                set garbageCollectdest to 120 seconds 
            }
            else
            {
                deactivate garbageCollectdes                    set expiredest to 180 seconds 
            }
        } 
    }
}*/

        //NOTE: add more psudo code here!!!
            // What should we put here or in a seperate function?

        return msg;
       }
       dbg(ROUTING_CHANNEL, "Unknown Packet Type %d\n", len);
       return msg;
   }
   


//--==Funcions==--＼＼

   //NOTE: Funcions we need:
        // •A way to update our "RoutingTable"
            // This will probubly be split between 2 funcions
                //One for the revice & another for our neighbors
        
        // • We could still use a generic mergeRoute

        // • A way to send the routing table

        // • void printRouteTable()

        // •
    //NOTE: Funcions we might need:
        // • A way to extractTable

        // • Maybe a seperate function to Add New rout To the RoutingTable
        
        // • Is in list function - depends on if we make our own dataStruct

        // • update cost function

        // •

        //Takes nighbor info and converts it to a Routing table for the updateRoutingTable funcion.
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
        
    //we may need to change this due to the changed payload
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


/*
A.1. RIP PSEUDO-CODE.

process RIPRouter

state:

    me                                          // ID of the router
    interfaces                                  // Set of router’s interfaces
    known                                       // Set of destinations with known routes
    hopsdest                                    // Estimated distance to dest
    nextRouterdest                              // Next router on the way to dest
    nextIfacedest                               // Interface over which the route advertisement was received 
    timer expiredest                            // Expiration timer for the route
    timer garbageCollectdest                    // Garbage collection timer for the route
    timer advertise                             // Timer for periodic advertisements

initially:
{
    known ← the set of all networks to which the router is connected. 
    for dest ∈ known
    {
        hopsdest = 1
        nextRouterdest = me
        nextIfacedest = the interface that connects the router to dest.
    }
    set advertise to 30 seconds 
}

events:
    receive RIP (router, dest, hopCnt) over iface 
    timeout (expiredest)
    timeout (garbageCollectdest)
    timeout (advertise)

    utility functions:
        broadcast (msg, iface) 
        {
          Broadcast message msg to all the routers attached to the network on the other side
          of interface iface. 
        }


event handlers:

receive RIP (router, dest, hopCnt) over iface 
{
    newMetric ← min (1 + hopCnt, 16)
    if (dest ∈/ known) and (newMetric < 16) then 
    {
        known ← known ∪ { dest } 
        hopsdest ← newMetric
        nextRouterdest ← router 
        nextIfacedest ← iface
        set expiredest to 180 seconds 
    } 
    else
    {
        if (hopsdest < 16 and router = nextRouterdest ) or (newMetric < hopsdest ) 
        {
            hopsdest ← newMetric
            nextRouterdest ← router
            nextIfacedest ← iface

            if (newMetric = 16) then 
            {
                deactivate expiredest
                set garbageCollectdest to 120 seconds 
            }
            else
            {
                deactivate garbageCollectdes                    set expiredest to 180 seconds 
            }
        } 
    }
}

timeout (expiredest) 
{
    hopsdest ← 16
    set garbageCollectdest to 120 seconds 
}

timeout (garbageCollectdest) 
{
    known ← known − { dest } 
}

timeout (advertise) 
{
    for each dest ∈ known do
     for each i ∈ interfaces do {
        if (i ̸= nextIfacedest) then {
            broadcast ([RIP (me, dest, hopsdest)], i) 
        } 
        else
        {
            broadcast ([RIP (me, dest, 16)], i) // Split horizon with poisoned reverse
        } 
    }
    set advertise to 30 seconds 
}
*/