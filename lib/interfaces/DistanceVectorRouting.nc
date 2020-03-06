//      Author:Nathan Blais
//Date Created:2020-02-16

interface DistanceVectorRouting{
     command void run();
     command void print();
     command error_t send(pack msg, uint16_t destination);
}