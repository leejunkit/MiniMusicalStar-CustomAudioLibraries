//
//  AudioFileRingBuffer.m
//  SimpleAudioRenderTest
//
//  Created by Jun Kit Lee on 11/8/11.
//  Copyright 2011 mohawk.riceball@gmail.com. All rights reserved.
//

#import "AudioFileRingBuffer.h"
#import "Audio.h"

@implementation AudioFileRingBuffer
@synthesize canStartReading, finishedReading, numFrames, currentFrameNum;

- (void)prepareAudioFile: (NSURL *)audioFileURL
{
    audioFile = [audioFileURL retain];
    //open the audio file
    xafref = 0;
    
    error = ExtAudioFileOpenURL((CFURLRef)audioFileURL, &xafref);
    
    //get the format of the audio file - what are we doing this for? nowhere else in the code needs this
    AudioStreamBasicDescription fileFormat;
    UInt32 propSize = sizeof(fileFormat);
    error = ExtAudioFileGetProperty(xafref, kExtAudioFileProperty_FileDataFormat, &propSize, &fileFormat);
    CheckError(error, "cannot get audio file data format");
    
    //create our output ASBD - we're also giving this to our mixer input
    ASBDSetCanonical(&asbd, 2, true);						
    asbd.mSampleRate = 44100.0;
    
    error = ExtAudioFileSetProperty(xafref, kExtAudioFileProperty_ClientDataFormat, sizeof(asbd), &asbd);
    CheckError(error, "cannot get kExtAudioFileProperty_ClientDataFormat");
    
    //get the file's length in sample frames
    numFrames = 0;
    propSize = sizeof(numFrames);
    error = ExtAudioFileGetProperty(xafref, kExtAudioFileProperty_FileLengthFrames, &propSize, &numFrames);
    CheckError(error, "cannot get file's length in sample frames");
    
    canStartReading = YES;
    
}

- (void)readAudioFileIntoRingBuffer
{
    if (!canStartReading)
    {
        printf("Cannot start reading file yet!");
        return;
    }

    //the amount of frames to read from the audio file into the buffer
    UInt32 inNumFrames = kInNumFrames;
    
    //make sure we don't read more than the total length.
    
    
    //if next read will exceed total length, just read the remaining frames left
    if ((currentFrameNum + kInNumFrames) > numFrames) {
        inNumFrames = (currentFrameNum + kInNumFrames) - numFrames;
    }
    
    //set up an AudioBufferList to temporarily store the read data before pushing into the buffer
    AudioBufferList tempBufList;
    tempBufList.mNumberBuffers = 1;
    tempBufList.mBuffers[0].mNumberChannels = asbd.mChannelsPerFrame;
    tempBufList.mBuffers[0].mDataByteSize = inNumFrames * sizeof(SInt16) * asbd.mChannelsPerFrame;
    tempBufList.mBuffers[0].mData = malloc(tempBufList.mBuffers[0].mDataByteSize); //must remember to free this later
    
    //do the actual reading
    if (finishedReading)
    {
        //if there are no more frames to read, just put silence into the buffers
        memset(tempBufList.mBuffers[0].mData, 0, tempBufList.mBuffers[0].mDataByteSize);
        //printf("Filling buffers with silence because there is nothing left to read for this audio file.\n");
    }
    
    else
    {
        error = ExtAudioFileRead(xafref, &inNumFrames, &tempBufList);
        if (error)
        {
            printf("ExtAudioFileRead result %ld %08X %4.4s\n", error, (unsigned int)error, (char*)&error); 
            free(tempBufList.mBuffers[0].mData);
            tempBufList.mBuffers[0].mData = 0;
            return;
        }
        
        //advance the read "pointer"
        currentFrameNum += inNumFrames;
    }
    
    //check inNumFrames, if it's now 0 (the ExtAudioFileRead sets it as such when there's nothing else to read, toggle finishedReading to YES
    if (inNumFrames == 0) finishedReading = YES;
    
    //take a lock on the buffer and push the contents of the temp buffer into the ringbuffer
    [bufferRecordLock lock];
    TPCircularBufferCopy(&bufferRecord, buffer, tempBufList.mBuffers[0].mData, inNumFrames * asbd.mChannelsPerFrame, sizeof(SInt16));
    [bufferRecordLock unlock];
    
    //free the malloc-ed temp buffer
    free(tempBufList.mBuffers[0].mData);

    
}

- (SInt16 *)readFromRingBufferNumberOfSamples:(int)samplesToRead
{
    while (samplesToRead > 0)
    {
        while (samplesToRead > TPCircularBufferFillCountContiguous(&bufferRecord)) {
            //printf("samplesToRead > TPCircularBuffer... now\n");
            [self readAudioFileIntoRingBuffer];
        }
        
        //printf("just before buffer lock for consumption\n");
        [bufferRecordLock lock];
        SInt16 *tempBuffer = buffer + TPCircularBufferTail(&bufferRecord);
        TPCircularBufferConsume(&bufferRecord, samplesToRead);
        samplesToRead = 0;
        
        [bufferRecordLock unlock];
        
        return tempBuffer;
    }
    
    //hopefully this doesn't happen! LOL
    return nil;
}

- (id)initWithAudioFile: (NSURL *)audioFileURL
{
    self = [super init];
    if (self) {
        canStartReading = NO;
        finishedReading = NO;
        
        //init the bufferRecord and malloc the ringbuffer
        TPCircularBufferInit(&bufferRecord, kBufferLength);
        buffer = (SInt16*)malloc(sizeof(SInt16) * kBufferLength); //remember to free this later
        
        [self prepareAudioFile:audioFileURL];
    }
    
    return self;
}

- (void)moveReadPositionOfAudioFileToFrame:(SInt64)targetFrame
{
    //check if new targetFrame is less than numFrames
    if (targetFrame >= numFrames) {
        currentFrameNum = numFrames;
        finishedReading = YES;
    }
    
    else {
        //change the seek position
        error = ExtAudioFileSeek(xafref, targetFrame);
        CheckError(error, "Cannot change seek location of audio file.");
        
        //set the current frame to the new targetFrame
        currentFrameNum = targetFrame;
    }
    
    //clear the ring buffer
    TPCircularBufferClear(&bufferRecord);
    
}

- (void)reset
{
    free(buffer);
    ExtAudioFileDispose(xafref);
    
    currentFrameNum = 0;
    canStartReading = NO;
    finishedReading =NO;
    
    //recreate the ring buffer
    //init the bufferRecord and malloc the ringbuffer
    TPCircularBufferInit(&bufferRecord, kBufferLength);
    buffer = (SInt16*)malloc(sizeof(SInt16) * kBufferLength); //remember to free this later
    
    [self prepareAudioFile:audioFile];

}

- (void)dealloc
{
    free(buffer);
    [audioFile release];
    ExtAudioFileDispose(xafref);
    [super dealloc];
}

@end
