/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    components FlooderC;
    Node.Flooder -> FlooderC.Flooder;

    components NeighborDiscoveryC;
    Node.NeighborDiscovery -> NeighborDiscoveryC;

    components  DistanceVectorRoutingC;
    Node.DistanceVectorRouting ->  DistanceVectorRoutingC;  

    components TransportC as Transport;
    Node.Transport -> Transport;  

    	   //Lists
    components new PoolC(reciveInfo, 20);
    components new QueueC(reciveInfo*, 20);

    Node.Pool -> PoolC;
    Node.Queue -> QueueC;
}
