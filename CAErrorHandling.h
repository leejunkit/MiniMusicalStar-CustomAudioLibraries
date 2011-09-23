//
//  CAErrorHandling.h
//  ThirdAttempt
//
//  Created by Jun Kit on 7/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
#include <AudioToolbox/AudioToolbox.h>

void CheckError(OSStatus error, const char *operation);