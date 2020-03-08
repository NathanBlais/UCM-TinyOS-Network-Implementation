/**
 * ANDES Lab - University of California, Merced
 * This class provides a simple list.
 *
 * @author UCM ANDES Lab
 * @author Alex Beltran
 * @date   2013/09/03
 *
 */

#include "../../includes/sendInfo.h"


generic module RouteTableC(uint16_t n){
	provides interface RouteTable;
}

implementation{
	uint16_t MAX_SIZE = n;

	route container[n];
	uint16_t size = 0;

	// Prototypes
	void mergeSort(uint16_t l,	uint16_t r);
	void merge(uint16_t l, uint16_t m, uint16_t r);

	command bool RouteTable.pushback(route input){
		// Check to see if we have room for the input.
		if(size < MAX_SIZE){
			// Put it in.
			container[size] = input;
			size++;
			return TRUE;
		 }
		return FALSE;
	}

	command bool RouteTable.pushfront(route input){
		// Check to see if we have room for the input.
		if(size < MAX_SIZE){
			int32_t i;
			// Shift everything to the right.
			for(i = size-1; i>=0; i--){
				container[i+1] = container[i];
			 }
			container[0] = input;
			size++;
			return TRUE;
		 }
		return FALSE;
	}

	command bool RouteTable.pushsort(route input){
		// Check to see if we have room for the input.
		if(size < MAX_SIZE){
			// Put it in.
			container[size] = input;
			size++;
			mergeSort(0, size);
			return TRUE;
		 }
		return FALSE;
	}

	command route RouteTable.popback(){
		route returnVal;

		returnVal = container[size];
		// We don't need to actually remove the value, we just need to decrement
		// the size.
		if(size > 0)size--;
		return returnVal;
	}

	command route RouteTable.popfront(){
		route returnVal;
		uint16_t i;

		returnVal = container[0];
		if(size>0){
			// Move everything to the left.
			for(i = 0; i<size-1; i++){
				container[i] = container[i+1];
			}
			size--;
		}
		return returnVal;
	}

	// This is similar to peek head.
	command route RouteTable.front(){
		return container[0];
	}

	// Peek tail
	command route RouteTable.back(){
		return container[size];
	}

	command bool RouteTable.isEmpty(){
		if(size == 0)
			return TRUE;
		else
			return FALSE;
	}

	command bool RouteTable.isFull(){
		if(size >= MAX_SIZE)
			return TRUE;
		else
			return FALSE;
	}	

	command uint16_t RouteTable.size(){
		return size;
	}

	command uint16_t RouteTable.maxSize(){
		return MAX_SIZE;
	}	

	command route RouteTable.get(uint16_t position){
		return container[position];
	}
	
	command route* RouteTable.getPointer(){ //consider geting rid of it
		return container;
	}

	command uint16_t RouteTable.getPosition(route newRoute)
	{
		uint16_t i;

		if (size != 0)
		{
			for (i = 0; i < size; i++)
			{
				if ((newRoute.Destination).id == (container[i].Destination).id)
				{
					return i;
				}
			}
		}
		return MAX_SIZE;
	}

	command void RouteTable.remove(uint16_t position) {
		uint8_t i;
		if(size > 0) {
		//Move everything beginning immediately after position to the left.
		for(i = position; i<size-1; i++){
			container[i] = container[i+1];
		}
		size--;
		}
	}


/* l is for left index and r is right index of the 
   sub-array of arr to be sorted */
void mergeSort(uint16_t l,	uint16_t r) 
{ 
    if (l < r) 
    { 
        // Same as (l+r)/2, but avoids overflow for 
        // large l and h 
        uint16_t m = l+(r-l)/2; 
  
        // Sort first and second halves 
        mergeSort(l, m); 
        mergeSort(m+1, r); 
  
        merge(l, m, r); 
    } 
} 

void merge(uint16_t l, uint16_t m, uint16_t r) 
{ 
	uint16_t i, j, k; 
    uint16_t n1 = m - l + 1;
    uint16_t n2 = r - m;
  
    /* create temp arrays */
    route L[n1], R[n2]; 
  
    /* Copy data to temp arrays L[] and R[] */
    for (i = 0; i < n1; i++) 
        L[i] = container[l + i]; 
    for (j = 0; j < n2; j++) 
        R[j] = container[m + 1 + j]; 
  
    /* Merge the temp arrays back into arr[l..r]*/
    i = 0; // Initial index of first subarray 
    j = 0; // Initial index of second subarray 
    k = l; // Initial index of merged subarray 
    while (i < n1 && j < n2) 
    { 
        if ((L[i].Destination).id <= (R[j].Destination).id) 
        { 
            container[k] = L[i]; 
            i++; 
        } 
        else
        { 
            container[k] = R[j]; 
            j++; 
        } 
        k++; 
    } 
  
    /* Copy the remaining elements of L[], if there 
       are any */
    while (i < n1) 
    { 
        container[k]= L[i]; 
        i++; 
        k++; 
    } 
  
    /* Copy the remaining elements of R[], if there 
       are any */
    while (j < n2) 
    { 
        container[k] = R[j]; 
        j++; 
        k++; 
    } 
} 

}
