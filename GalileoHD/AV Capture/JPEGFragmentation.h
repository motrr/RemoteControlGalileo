//  Created by Chris Harding on 14/06/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import <Foundation/Foundation.h>

// Structure for JPEG fragment headers
typedef struct {
    
    unsigned short int  frame_number; // Sequence number of the frame
    unsigned short int  fragment_offset; // Where to insert the fragment
    unsigned short int  fragment_length; // Length of the fragment
    unsigned short int  total_length; // Total length of the frame
    unsigned short int  magic_number; // For debugging
    
} JPEGFragmentHeaderStruct;

#define MAX_FRAGMENT_LENGTH 1400
#define JPEG_HEADER_LENGTH  10
