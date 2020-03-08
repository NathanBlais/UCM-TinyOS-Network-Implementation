/**
 * ANDES Lab - University of California, Merced
 * This class provides a simple list.
 *
 * @author UCM ANDES Lab
 * @author Alex Beltran
 * @date   2013/09/03
 * 
 */

interface RouteTable{
   /**
    * Put value into the end of the list.
    *
    * @param input - data to be inserted
    */
    command bool pushback(route input);
	command bool pushfront(route input);
	command bool pushsort(route input);

	command route popback();
	command route popfront();

	command route front();
	command route back();

	command bool isEmpty();
	command bool isFull();

	command uint16_t size();
	command uint16_t maxSize();

	command route get(uint16_t position);
	command route* getPointer();
	command uint16_t getPosition(route newRoute);


	command void remove(uint16_t position);
}
