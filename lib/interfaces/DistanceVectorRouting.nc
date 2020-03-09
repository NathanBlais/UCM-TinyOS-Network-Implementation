//      Author:Nathan Blais
//Date Created:2020-02-16

interface DistanceVectorRouting{
     command void run();
     command void print();
     command uint16_t GetNextHop(uint16_t destination);

}