//
//  BoomzAUOutputCapturer.m
//  ThirdAttempt
//
//  Created by Jun Kit on 7/6/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "BoomzAUOutputCapturer.h"


@implementation BoomzAUOutputCapturer

static OSStatus RenderCallback(	void *							inRefCon,
                               AudioUnitRenderActionFlags *	ioActionFlags,
                               const AudioTimeStamp *			inTimeStamp,
                               UInt32							inBusNumber,
                               UInt32							inNumberFrames,
                               AudioBufferList *				ioData)
{
    if (*ioActionFlags & kAudioUnitRenderAction_PostRender) {
        BoomzAUOutputCapturer *This = (BoomzAUOutputCapturer *)inRefCon;
        static int TEMP_kAudioUnitRenderAction_PostRenderError	= (1 << 8);
        if (This->mBusNumber == inBusNumber && !(*ioActionFlags & TEMP_kAudioUnitRenderAction_PostRenderError)) {
            OSStatus result = ExtAudioFileWriteAsync(This->mExtAudioFile, inNumberFrames, ioData);
            CheckError(result, "Error writing frames!");
        }
    }
    return noErr;
}

-(BoomzAUOutputCapturer *) initWithAudioUnit: (AudioUnit)au OutputURL: (CFURLRef)outputFileURL AudioFileTypeID: (AudioFileTypeID)fileType forBusNumber: (int)busNumber
{
    self = [super init];
    if (self)
    {
        mFileOpen = false;
        mClientFormatSet = false;
        mAudioUnit = au;
        mExtAudioFile = NULL;
        
        //should be changeable (set to 0 to record the entire mix (VERY LAGGY THOUGH), set to 1 to record just mic)
        mBusNumber = busNumber;
        
        //ASBDSetCanonical(&format, 2, YES);
        ASBDSetIMA4(&format, 2);
        
    }
    
    {
        CFShow(outputFileURL);
        error = ExtAudioFileCreateWithURL(outputFileURL, fileType, &format, NULL, kAudioFileFlags_EraseFile, &mExtAudioFile);
        CheckError(error, "Cannot execute ExtAudioFileCreateWithURL");
        
        if (!error)
        {
            mFileOpen = true;
        }
        
    }
    
    return self;
}

-(void) start
{
    if (mFileOpen) {
        if (!mClientFormatSet) {
            AudioStreamBasicDescription clientFormat;
            UInt32 size = sizeof(clientFormat);
            AudioUnitGetProperty(mAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, mBusNumber, &clientFormat, &size);
            ExtAudioFileSetProperty(mExtAudioFile, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat);
            mClientFormatSet = true;
        }
        ExtAudioFileWriteAsync(mExtAudioFile, 0, NULL);	// initialize async writes
        AudioUnitAddRenderNotify(mAudioUnit, RenderCallback, self);
    }
}

-(void) stop
{
    if (mFileOpen)
        AudioUnitRemoveRenderNotify(mAudioUnit, RenderCallback, self);
}

-(void) close
{
    if (mExtAudioFile) {
        ExtAudioFileDispose(mExtAudioFile);
        mExtAudioFile = NULL;
    }
}

-(void) dealloc
{
    [self close];
    [super dealloc];
}

@end
