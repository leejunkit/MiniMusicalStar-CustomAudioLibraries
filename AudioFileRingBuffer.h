//
//  AudioFileRingBuffer.h
//  SimpleAudioRenderTest
//
//  Created by Jun Kit Lee on 11/8/11.
//  Copyright 2011 mohawk.riceball@gmail.com. All rights reserved.
//
#define kBufferLength 4096
#define kInNumFrames 1024

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TPCircularBuffer.h"
#import "ASBDHelper.h"
#import "CAErrorHandling.h"

@interface AudioFileRingBuffer : NSObject {
    OSStatus error;
    
    //the following ivars store information about the currently loaded audio file
    NSURL *audioFile;
    ExtAudioFileRef xafref; //reference to the current open audio file
    AudioStreamBasicDescription asbd; //ouput asbd, audio file is converted to this format, and remoteio output is also this format
    UInt64 numFrames; //this numFrames is how many frames total in the audio file 
    UInt64 currentFrameNum; //the current playing position of the file in frames
    
    //using the TPCircularBuffer instead
    SInt16 *buffer;
    TPCircularBufferRecord bufferRecord;
    NSLock *bufferRecordLock;
    
    //state flags
    bool canStartReading;
    bool finishedReading;
}

@property (nonatomic, readonly) UInt64 numFrames;
@property (nonatomic, readonly) UInt64 currentFrameNum;
@property (nonatomic, readonly) bool canStartReading;
@property (nonatomic, readonly) bool finishedReading;

- (void)prepareAudioFile: (NSURL *)audioFileURL;
- (void)readAudioFileIntoRingBuffer;
- (SInt16 *)readFromRingBufferNumberOfSamples:(int)samplesToRead;
- (id)initWithAudioFile: (NSURL *)audioFileURL;
- (void)moveReadPositionOfAudioFileToFrame:(SInt64)targetFrame;
- (void)reset;

@end
