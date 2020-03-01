//Author:Nathan Blais

configuration NeighborDiscoveryC{
	provides interface NeighborDiscovery;
}

implementation {
	//Export the implemention
	components NeighborDiscoveryP;	
	NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

	components RandomC as Random;
	
	//Wire the SimpleSend interface used by NeighborDiscoveryP to the one provided by SimpleSendC
	components new SimpleSendC(AM_NEIGHBOR) as Sender;
	NeighborDiscoveryP.Sender -> Sender;
	
	//Wire the Receive interface used by NeighborDiscoveryP to the one provided by AMReceiverC()
	components new AMReceiverC(AM_NEIGHBOR) as Receiver;
	NeighborDiscoveryP.Receiver -> Receiver;

    NeighborDiscoveryP.AMPacket -> Receiver;

	//Wire the List interface used by NeighborDiscoveryP to the one provided by ListC()
    components new ListC(neighbor, 20) as Neighborhood;
    NeighborDiscoveryP.Neighborhood -> Neighborhood;

	components new TimerMilliC() as periodicTimer; //create a new timer with alias "myTimerC"
	NeighborDiscoveryP.periodicTimer -> periodicTimer;
	
}