//Author:Nathan Blais
interface NeighborDiscovery{
	command void run();
	command void print();
	command uint8_t* getNeighbors();
	command uint16_t getNeighborhoodSize();

}