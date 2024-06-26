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

	components new TimerMilliC(), LocalTimeMilliC;
    TransportP.LocalTime -> LocalTimeMilliC;

	components new TimerMilliC() as Timer;
    TransportP.Timer -> Timer;

    // components new ListC(sendTCPInfo, 20) as SendBuff;
    // TransportP.SendBuff -> SendBuff;
	
	// components new ListC(sendTCPInfo, 20) as ReSendBuff;
    // TransportP.ReSendBuff -> ReSendBuff;

	//Lists
   	components new PoolC(pack, 100);
   	components new QueueC(pack*, 100);
	components new PoolC(sendTCPInfo, 20) as SendPoolC;
	components new QueueC(sendTCPInfo*, 20) as SendQueueC;

	// components new PoolC(sendTCPInfo, 20) as ReSendPoolC;
	// components new QueueC(sendTCPInfo*, 20) as ReSendQueueC;

   	TransportP.Pool -> PoolC;
	 TransportP.SendPool -> SendPoolC;
	// TransportP.ReSendPool -> ReSendPoolC;
   	TransportP.Queue -> QueueC;
   	 TransportP.SendQueue -> SendQueueC;
	// TransportP.ReSendQueue -> ReSendQueueC;


}