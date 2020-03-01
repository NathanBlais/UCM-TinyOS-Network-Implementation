//      Author:Nathan Blais
//Date Created:2020-02-16

configuration DistanceVectorRoutingC{
	provides interface DistanceVectorRouting;
}

implementation {
	//Export the implemention
	components DistanceVectorRoutingP;	
	DistanceVectorRouting = DistanceVectorRoutingP.DistanceVectorRouting;
	
	//Wire the SimpleSend interface used by FloodeP to the one provided by SimpleSendC
	components new SimpleSendC(AM_ROUTING) as Sender;
	DistanceVectorRoutingP.Sender -> Sender;
	
	//Wire the Receive interface used by DistanceVectorRoutingP to the one provided by AMReceiverC()
	components new AMReceiverC(AM_ROUTING) as Receiver;
	DistanceVectorRoutingP.Receiver -> Receiver;
    DistanceVectorRoutingP.AMPacket -> Receiver;

	//Wire the List interface used by DistanceVectorRoutingP to the one provided by ListC()
    components new ListC(pack, 20) as PacketsList;
    DistanceVectorRoutingP.KnownPacketsList -> KnownPacketsList;

	components NeighborDiscoveryC;
    DistanceVectorRoutingP.NeighborDiscovery -> NeighborDiscoveryC;

	components new ListC(route, MAX_ROUTES) as Routes;
    DistanceVectorRoutingP.Routes -> Routes;
}