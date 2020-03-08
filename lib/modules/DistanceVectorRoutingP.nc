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
    //Provides the SimpleSend interface in order to flood packets
    provides interface DistanceVectorRouting;
    //Uses the SimpleSend interface to forward recieved packet as broadcast
    uses interface SimpleSend as Sender;
    //Uses the Receive interface to determine if received packet is meant for me.
    uses interface Receive as Receiver;
    uses interface AMPacket;
    //Uses the Queue interface to determine if packet recieved has been seen before
    uses interface List<pack> as PacketsList;
    //NOTE:remember to store src & seq for each node
    uses interface NeighborDiscovery;
    uses interface List<route> as Routes;
    //make temporary list

    uses interface Timer<TMilli> as periodicTimer;

    uses interface Random;

    //NOTE: Wire a timmer
}

implementation
{
    uint16_t SEQ_NUM = 1;
	pack sendPackage;
    
    //uint8_t * neighbors;


    route routeHolder;

    void updateRoutingTable(route * newRoutes, uint16_t size);

    void UpdateNeighborRoutingTable();

    void mergeRoute(route * newRoute);

    void printRouteTable();

    uint16_t pointerArrayCounter(uint8_t * pointer);


    void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, route * payload, uint8_t length);



    command void DistanceVectorRouting.run()
    {
        uint8_t i;
        uint8_t costHolder;
        call periodicTimer.startPeriodic(100000 + (call Random.rand16() %300) ); //add random #


         for(i=0; i < 20 /*MAX_ROUTES*/; i++){
            if(i+1 != TOS_NODE_ID){
                routeHolder.Destination = i+1;
                routeHolder.Cost = MAX_ROUTES;
                //routeHolder.NextHop = ?;
                routeHolder.TTL = 0;
                call Routes.pushback(routeHolder);}
            else{
                routeHolder.Destination = i+1;
                routeHolder.Cost = 0;
                //routeHolder.NextHop = TOS_NODE_ID;
                routeHolder.TTL = 0;
                call Routes.pushback(routeHolder);
            }
         }

    }

    command void DistanceVectorRouting.print()
    {
        printRouteTable();
    }

    event void periodicTimer.fired()
    {
        uint8_t i, j=0;
        dbg(ROUTING_CHANNEL, "PeriodicTimer fired from Routing\n");
        // update Router list form neighbor list
        UpdateNeighborRoutingTable();

        //do Split Horizon with posion

        //  for(i=0; i < call Routes.size(); i++){
        //      if((call Routes.get(i)).Destination = (call NeighborDiscovery.getNeighbors())[i] )
        //      routeHolder

        //  }




        dbg(ROUTING_CHANNEL, "Sending from DVR\n");

        //optional - call a function to organize the list

        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1, SEQ_NUM, PROTOCOL_DV, call Routes.getPointer(), sizeof(route) * ;
 
        //                              dbg(ROUTING_CHANNEL, "Package Payload: %s\n", TEMP[0]);
                  dbg(ROUTING_CHANNEL, "Package Payload: %d\n", sendPackage.payload);

        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
    }



    //NOTE: Make a run command that starts after a random ammount of time.

    

//Broadcast packet
	command error_t DistanceVectorRouting.send(pack msg, uint16_t dest)
	{
		//Attempt to send the packet
		dbg(ROUTING_CHANNEL, "Sending from Router\n");

		if (call Sender.send(msg, AM_BROADCAST_ADDR) == SUCCESS)
		{
			return SUCCESS;
		}
		return FAIL;
	}

//Event signaled when a DVRouter recieves a packet
   event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len){
      dbg(ROUTING_CHANNEL, "Packet Received in VRouter\n");
      if(len==sizeof(pack)){
                  uint8_t i;
        pack* myMsg=(pack*) payload;
        route* routes = (route*) myMsg->payload;



        //int16_t size = pointerArrayCounter(.payload));

        //dbg(ROUTING_CHANNEL, "Size in RECIVER: %d\n", size);

        //dbg(GENERAL_CHANNEL, "RECIVER sizeof(myMsg->payload) = %d\n", sizeof(myMsg->payload));


       // for(i=0;i<200 route[])(myMsg->payload)[0]))
       //     newRoute->NextHop = TOS_NODE_ID;

        for(i = 0; i < MAX_ROUTES && routes[i].Destination != 0; i++){
            if(routes[i].NextHop = TOS_NODE_ID || routes[i].Destination == myMsg->src){
                routes[i].NextHop = MAX_TTLroute;
            }
            else{
                routes[i].NextHop = myMsg->src;
            }
            dbg(GENERAL_CHANNEL, "RECIVER routes[i].Cost = %d\n", routes[i].Cost);
        }

        

         updateRoutingTable(routes, i);

         return msg;
      }
      dbg(ROUTING_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }

    // uint16_t pointerArrayCounter(uint8_t * pointer){
    //     uint16_t i;

    //     for (i = 0; i < 200 && pointer[i] != 0; i++){} //19 is the max size of neighbor list{}
    //     return i;
    // }


    //Takes nighbor info and converts it to a Routing table for the updateRoutingTable funcion.
    void UpdateNeighborRoutingTable(){
        uint16_t i;
        uint8_t * neighbors = call NeighborDiscovery.getNeighbors();
        uint16_t size = call NeighborDiscovery.getNeighborhoodSize(); //pointerArrayCounter(neighbors);
        route neighborRoutes[size]; //maximum number of neighbors 20??

        dbg(GENERAL_CHANNEL, "Size = %d\n", size);

        for (i = 0; i < size; i++){
            //use a Temporary route to insert neighbor info into routing table
            neighborRoutes[i].Destination = neighbors[i];
            neighborRoutes[i].NextHop = neighbors[i];
            neighborRoutes[i].Cost = 0; /* distance metric */ //temprarily for NumOfHops
            neighborRoutes[i].TTL = MAX_TTLroute;
        }
        updateRoutingTable(neighborRoutes, i);

    }


    /*
    The procedure updateRoutingTable is the main routine that calls mergeRoute
    to incorporate all the routes contained in a routing update that is received
    from a neighboring node. */
 
    void updateRoutingTable(route * newRoutes, uint16_t size)
    {
        int i;
        for (i = 0; i < size; ++i)
        {
            if(newRoutes[i].Destination != TOS_NODE_ID)
                mergeRoute(&newRoutes[i]);
        }
    }



/*
The routine that updates the local node’s routing table based on a new route is given by mergeRoute. 
Although not shown, a timer function periodically scans the list of routes in the node’s routing table,
decrements the TTL (time to live) field of each route, and discards any routes that have a time to live of 0. 
Notice, however, that the TTL field is reset to MAX TTL any time the route is reconfirmed by an update message 
from a neighboring node.
*/
    void
        mergeRoute(route * newRoute) {
        uint16_t i;
        route * table = call Routes.getPointer();
        for (i = 0; i < (call Routes.size()) + 1; i++)
        {
            if (newRoute->Destination == (call Routes.get(i)).Destination)
            {

                if (newRoute->Destination == 0)
                {
                    return;
                }
                if (newRoute->Cost + 1 < (call Routes.get(i)).Cost)
                {
                    /* found a better route: */    
                    break;
                }
                // else if (newRoute->NextHop == (call Routes.get(i)).NextHop)
                // {
                //     /* metric for current next-hop may have changed: */
                //     break;
                // }
                else
                {
                    /* route is uninteresting---just ignore it */
                    return;
                }
            }
        }
        if (i == call Routes.size())
        {
            /* this is a completely new route; is there room for it? */
            if (i >= MAX_ROUTES)
                return; /* can't fit this route in table so give up */
        }


        //(call Routes.get(i)).Destination = MAX_TTLroute; ///Do we want to update the TTL to MAX_TTL every time we get an update
        table[i].NextHop = newRoute->NextHop; ///Do we want to update the TTL to MAX_TTL every time we get an update

        dbg(GENERAL_CHANNEL, "1newRoute->Cost = %d\n", newRoute->Cost);
        dbg(GENERAL_CHANNEL, "2table[i].Cost = %d\n", table[i].Cost);
        table[i].Cost = newRoute->Cost + 1; /* account for hop to get to next node */ 
        dbg(GENERAL_CHANNEL, "2newRoute->Cost = %d\n", newRoute->Cost;
        dbg(GENERAL_CHANNEL, "2table[i].Cost = %d\n", table[i].Cost);
        table[i].TTL = MAX_TTLroute; ///Do we want to update the TTL to MAX_TTL every time we get an update


        //call Routes.pushback(*newRoute);

        /* reset TTL */
    }

    void printRouteTable()
    {
        uint16_t size = call Routes.size();
        uint8_t i;
        route node;

        dbg(GENERAL_CHANNEL, "Node %d Route List:\n", TOS_NODE_ID);

        for (i = 0; i < size; i++)
        {
            node = call Routes.get(i);
            dbg(GENERAL_CHANNEL, "\t\tDestination: %d Cost: %d NextHop: %d TTL: %d\n", node.Destination, node.Cost, node.NextHop, node.TTL);
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

}