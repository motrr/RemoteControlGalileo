#ifndef __OSXTimer_H__
#define __OSXTimer_H__

#include <sys/time.h> 
#include <sys/times.h> 

/** Timer class */
class Timer
{
private:
	struct timeval mStart;
	clock_t mZeroClock;
public:
	Timer()
	{
		reset();
	}
	
	~Timer() {}

	/** Resets timer */
	void reset()
	{
		mZeroClock = clock();
		gettimeofday(&mStart, NULL);
	}

	/** Returns milliseconds since initialisation or last reset */
	unsigned long getMilliseconds()
	{
		struct timeval now;
		gettimeofday(&now, NULL);
		return (now.tv_sec - mStart.tv_sec) * 1000 + (now.tv_usec - mStart.tv_usec) / 1000;
	}

	/** Returns microseconds since initialisation or last reset */
	unsigned long getMicroseconds()
	{
		struct timeval now;
		gettimeofday(&now, NULL);
		return (now.tv_sec - mStart.tv_sec) * 1000000 + (now.tv_usec - mStart.tv_usec);
	}

	/** Returns milliseconds since initialisation or last reset, only CPU time measured */	
	unsigned long getMillisecondsCPU()
	{
		clock_t newClock = clock();
		return (unsigned long)((float)(newClock - mZeroClock) / ((float)CLOCKS_PER_SEC / 1000.0)) ;
	}

	/** Returns microseconds since initialisation or last reset, only CPU time measured */	
	unsigned long getMicrosecondsCPU()
	{
		clock_t newClock = clock();
		return (unsigned long)((float)(newClock - mZeroClock) / ((float)CLOCKS_PER_SEC / 1000000.0)) ;
	}
};

#endif
