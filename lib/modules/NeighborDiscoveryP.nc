//Author:Nathan Blais
#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

module NeighborDiscoveryP
{

    //Provides the interface
    provides interface NeighborDiscovery;
    //Uses SimpleSend interface to forward recieved packet from broadcast
    uses interface SimpleSend as Sender;
    //Uses the Receive interface to determine if received packet is meant for itself.
    uses interface Receive as Receiver;
    uses interface AMPacket;
    //Uses the List interface to store a list of Neighbors
    uses interface List<neighbor> as Neighborhood;
    uses interface Timer<TMilli> as periodicTimer;
}

implementation
{

    pack sendPackage;
    neighbor neighborHolder;
    uint16_t SEQ_NUM = 0;
    uint8_t tmp = 8; //put in to avoid warning
    uint8_t *temp = &tmp;

    void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t * payload, uint8_t length);

    bool isNeighbor(uint8_t nodeid);
    error_t addNeighbor(uint8_t nodeid);
    void updateNeighbors();
    void printNeighborhood();

//    uint8_t neighbors[19]; //Maximum of 20 neighbors?

    command void NeighborDiscovery.run()
    {
        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1, SEQ_NUM, PROTOCOL_PING, temp, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);

        call periodicTimer.startPeriodic(100000);
    }

    event void periodicTimer.fired()
    {
        dbg(NEIGHBOR_CHANNEL, "Sending from NeighborDiscovery\n");
        updateNeighbors();

        //optional - call a funsion to organize the list
        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 1, SEQ_NUM, PROTOCOL_PING, temp, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
    }

    command void NeighborDiscovery.print()
    {
        printNeighborhood();
    }

    event message_t *Receiver.receive(message_t * msg, void *payload, uint8_t len)
    {
        if (len == sizeof(pack)) //check if there's an actual packet
        {
            pack *contents = (pack *)payload;
            dbg(NEIGHBOR_CHANNEL, "NeighborReciver Called \n");

            if (PROTOCOL_PING == contents->protocol) //got a message, not a reply
            {

                contents->src = TOS_NODE_ID;
                contents->dest = call AMPacket.source(msg);
                contents->TTL = (contents->TTL) - 1;
                contents->protocol = PROTOCOL_PINGREPLY;

                dbg(NEIGHBOR_CHANNEL, "Sending Neighbor Ping Reply\n");
                call Sender.send(*contents, contents->dest);
                return msg;
            }

            else if (PROTOCOL_PINGREPLY == contents->protocol) //we made replies be of one
            {
                if (isNeighbor(contents->src) == TRUE)
                {
                    int i;
                    uint16_t size = 25; //call Neighborhood.size();

                    for (i = 0; i < size; i++)
                    {
                        if (contents->src == (call Neighborhood.get(i)).id)
                        {
                            neighbor *nodes = call Neighborhood.getPointer();
                            nodes[i].flag = FALSE;
                            return msg;
                        }
                    }
                }
                else
                {
                    addNeighbor(contents->src);
                    //dbg(NEIGHBOR_CHANNEL, "This packet is a neighbor of the node %d and it's node number is &d", TOS_NODE_ID,  );
                }
            }
            else
            {
                dbg(NEIGHBOR_CHANNEL, "Unknown Protocal %d\n", len);
                return msg;
            }
        }

        dbg(NEIGHBOR_CHANNEL, "Unknown Packet Type %d\n", len);
        return msg;
    }

    void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t seq, uint16_t protocol, uint8_t * payload, uint8_t length)
    {
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }

    //Function to check if packet matches a packet in Neighborhood
    bool isNeighbor(uint8_t nodeid)
    {
        uint16_t size = call Neighborhood.size();
        uint8_t i;
        neighbor node;
        if (!call Neighborhood.isEmpty())
        {
            for (i = 0; i < size; i++)
            {
                node = call Neighborhood.get(i);
                if (node.id == nodeid)
                    return TRUE;
            }
        }
        return FALSE;
    }

    //Function to add packet to Neighborhood. If the list is full the last element is
    //removed and the new packet added. Does not check if a packet is already in the list.
    error_t addNeighbor(uint8_t nodeid) //might want to implement this diffrently
    {
        //uint16_t size = call Neighborhood.size();
        neighbor node;
        node.id = nodeid;
        node.flag = FALSE;

        if (call Neighborhood.pushback(node) == TRUE)
            return SUCCESS;
        else
        {
            call Neighborhood.popfront();
            if (call Neighborhood.pushback(node) == TRUE)
                return SUCCESS;
            else
                return FAIL;
        }
    }
    void updateNeighbors()
    {
        uint16_t size = call Neighborhood.size();
        uint8_t i;
        neighbor *nodes = call Neighborhood.getPointer();

        if (!call Neighborhood.isEmpty())
        {
            for (i = 0; i < size; i++)
            {
                if (nodes[i].flag == TRUE)
                    call Neighborhood.remove(i);
                else
                    nodes[i].flag = TRUE;
            }
        }
    }

    void printNeighborhood()
    {
        uint16_t size = call Neighborhood.size();
        uint8_t i;
        neighbor node;

        dbg(GENERAL_CHANNEL, "Node %d Neighbor List:\n", TOS_NODE_ID);

        for (i = 0; i < size; i++)
        {
            node = call Neighborhood.get(i);
            dbg(GENERAL_CHANNEL, "\t\tNode: %d Flag: %d\n", node.id, node.flag);
        }
    }

    command uint8_t *NeighborDiscovery.getNeighbors()
    {
        //First zero out neighbors array
        uint8_t i, size = call Neighborhood.size();


        neighbor node;
        uint8_t neighbors[size]; //Maximum of 20 neighbors?

        for (i = 0; i < 19; i++)
        {
            neighbors[i] = 0;
        }

        //Then populate based on Neighborhood
        for (i = 0; i < size; i++)
        {
            node = call Neighborhood.get(i);
            neighbors[i] = node.id;
        }
        dbg(GENERAL_CHANNEL, "Nsizeof(neighbors) = %d\n", sizeof(neighbors));

        return neighbors;
    }

    command uint16_t NeighborDiscovery.getNeighborhoodSize(){
        return call Neighborhood.size();
    }


} // for implementation