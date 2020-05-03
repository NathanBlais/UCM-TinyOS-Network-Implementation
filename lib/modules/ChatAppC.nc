configuration ChatAppC{
	provides interface ChatApp;
}

implementation {
	components ChatAppP;	
	ChatApp = ChatAppP.ChatApp;
	
	// components new HashmapC(socket_store_t, MAX_NUM_OF_SOCKETS) as Connections;
    // TransportP.Connections->Connections;

	// components new TimerMilliC(), LocalTimeMilliC;
    // TransportP.LocalTime -> LocalTimeMilliC;

	// components new TimerMilliC() as Timer;
    // TransportP.Timer -> Timer;

    // components new ListC(sendTCPInfo, 20) as SendBuff;
    // TransportP.SendBuff -> SendBuff;
	
	// components new ListC(sendTCPInfo, 20) as ReSendBuff;
    // TransportP.ReSendBuff -> ReSendBuff;

	//Lists
   	// components new PoolC(pack, 100);
   	// components new QueueC(pack*, 100);
	// components new PoolC(sendTCPInfo, 20) as SendPoolC;
	// components new QueueC(sendTCPInfo*, 20) as SendQueueC;

	// // components new PoolC(sendTCPInfo, 20) as ReSendPoolC;
	// // components new QueueC(sendTCPInfo*, 20) as ReSendQueueC;

   	// TransportP.Pool -> PoolC;
	//  TransportP.SendPool -> SendPoolC;
	// // TransportP.ReSendPool -> ReSendPoolC;
   	// TransportP.Queue -> QueueC;
   	//  TransportP.SendQueue -> SendQueueC;
	// // TransportP.ReSendQueue -> ReSendQueueC;


}