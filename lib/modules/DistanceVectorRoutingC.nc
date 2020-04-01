//      Author:Nathan Blais
//Date Created:2020-02-16

configuration DistanceVectorRoutingC{
	provides interface DistanceVectorRouting;
}

implementation {
	//Export the implemention
	components DistanceVectorRoutingP;	
	DistanceVectorRouting = DistanceVectorRoutingP.DistanceVectorRouting;
	
	//Wire the SimpleSend interface used by DistanceVectorRoutingP to the one provided by SimpleSendC
	components new SimpleSendC(AM_ROUTING) as Sender;
	DistanceVectorRoutingP.Sender -> Sender;
	
	//Wire the Receive interface used by DistanceVectorRoutingP to the one provided by AMReceiverC()
	components new AMReceiverC(AM_ROUTING) as Receiver;
	DistanceVectorRoutingP.Receiver -> Receiver;
    DistanceVectorRoutingP.AMPacket -> Receiver;

	//Wire the NeighborDiscovery interface used by DistanceVectorRoutingP to the one provided byNeighborDiscoveryC
	components NeighborDiscoveryC;
    DistanceVectorRoutingP.NeighborDiscovery -> NeighborDiscoveryC;

    
    components new TimerMilliC() as InitalizationWait; //create a new timer with alias "myTimerC"
	DistanceVectorRoutingP.InitalizationWait -> InitalizationWait;

	components new TimerMilliC() as advertiseTimer; //create a new timer with alias "myTimerC"
	DistanceVectorRoutingP.advertiseTimer -> advertiseTimer;


	components RandomC as Random; // Used to randomize Timer
	DistanceVectorRoutingP.Random -> Random;

	components new RouteTableC(MAX_ROUTES);
	DistanceVectorRoutingP.RouteTable -> RouteTableC;


//QUESTION:Which of these do we want to use

	//Wire the List interface used by DistanceVectorRoutingP to the one provided by ListC()
    components new ListC(pack, 20) as PacketsList;
    DistanceVectorRoutingP.PacketsList -> PacketsList;


	   //Lists
   components new PoolC(reciveInfo, 100);
   components new QueueC(reciveInfo*, 100);

   DistanceVectorRoutingP.Pool -> PoolC;
   DistanceVectorRoutingP.Queue -> QueueC;


}