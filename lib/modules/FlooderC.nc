//Author:Nathan Blais

configuration FlooderC{
	provides interface Flooder;
}

implementation {
	components FlooderP;	
	Flooder = FlooderP.Flooder;
	
	//Wire the SimpleSend interface used by FloodeP to the one provided by SimpleSendC
	components new SimpleSendC(AM_FLOODING) as Sender;
	FlooderP.Sender -> Sender;
	
	//Wire the Receive interface used by FlooderP to the one provided by AMReceiverC()
	components new AMReceiverC(AM_FLOODING) as Receiver;
	FlooderP.Receiver -> Receiver;
    FlooderP.AMPacket -> Receiver;

	//Wire the List interface used by FlooderP to the one provided by ListC()
    components new ListC(pack, 20) as KnownPacketsList;
    FlooderP.KnownPacketsList -> KnownPacketsList;

	//Wire the NeighborDiscovery interface used by FlooderP to the one provided by NeighborDiscoveryC()
	components NeighborDiscoveryC;
    FlooderP.NeighborDiscovery -> NeighborDiscoveryC;
}