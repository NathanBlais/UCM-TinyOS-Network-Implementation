#include "../../includes/am_types.h"

generic configuration SimpleSendConfig(int channel){
   provides interface SimpleSend;
}

implementation{
   components new SimpleSendC();
   SimpleSend = SimpleSendC.SimpleSend;

   components new TimerMilliC() as sendTimer;
   components RandomC as Random;
   components new AMSenderC(channel);

   //Timers
   SimpleSendC.sendTimer -> sendTimer;
   SimpleSendC.Random -> Random;

   SimpleSendC.Packet -> AMSenderC;
   SimpleSendC.AMPacket -> AMSenderC;
   SimpleSendC.AMSend -> AMSenderC;

   //Lists
   components new PoolC(sendInfo, 20);
   components new QueueC(sendInfo*, 20);

   SimpleSendC.Pool -> PoolC;
   SimpleSendC.Queue -> QueueC;
}
