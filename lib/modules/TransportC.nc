//      Author:Nathan Blais
//Date Created:2020-03-21

configuration TransportC{
	provides interface Transport;
}

implementation {
	components TransportP;	
	Transport = TransportP.Transport;
	
	//Wire the SimpleSend interface used by TransportP to the one provided by SimpleSendC
	components new SimpleSendC(AM_PACK) as Sender;
	TransportP.Sender -> Sender;
	
	//Wire the Receive interface used by TransportP to the one provided by AMReceiverC()
//	components new AMReceiverC(AM_TCP) as Receiver;
//	TransportP.Receiver -> Receiver;
//    TransportP.AMPacket -> Receiver;

	//Wire the DistanceVectorRouting interface used by TransportP to the one provided by DistanceVectorRoutingC()
    components  DistanceVectorRoutingC;
    TransportP.DistanceVectorRouting ->  DistanceVectorRoutingC; 

	components new HashmapC(socket_store_t, MAX_NUM_OF_SOCKETS) as Connections;
    TransportP.Connections->Connections;

	components new TimerMilliC() as sendPacketTimer;
    TransportP.sendPacketTimer -> sendPacketTimer;

	components new TimerMilliC() as sendDataTimer;
    TransportP.sendDataTimer -> sendDataTimer;

    //NOTE: wire timmers 


	//Lists
   	components new PoolC(pack, 100);
   	components new QueueC(pack*, 100);

   	TransportP.Pool -> PoolC;
   	TransportP.Queue -> QueueC;



}