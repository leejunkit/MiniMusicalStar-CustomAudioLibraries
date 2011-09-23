//
//  BoomzAUOutputCapturer.h
//  ThirdAttempt
//
//  Created by Jun Kit on 7/6/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/ExtendedAudioFile.h>
#import "ASBDHelper.h"
#import "CAErrorHandling.h"

@interface BoomzAUOutputCapturer : NSObject {
    bool				mFileOpen;
	bool				mClientFormatSet;
	AudioUnit			mAudioUnit;
	ExtAudioFileRef		mExtAudioFile;
	UInt32				mBusNumber;
    
    AudioStreamBasicDescription format;
    OSStatus            error;
}

-(BoomzAUOutputCapturer *) initWithAudioUnit: (AudioUnit)au OutputURL: (CFURLRef)outputFileURL AudioFileTypeID: (AudioFileTypeID)fileType forBusNumber: (int)busNumber;
-(void) start;
-(void) stop;
-(void) close;
-(void) dealloc;
@end
