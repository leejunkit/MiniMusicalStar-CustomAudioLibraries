//
//  MixPlayerRecorder.m
//  SimpleAudioRenderTest
//
//  Created by Jun Kit Lee on 11/8/11.
//  Copyright 2011 mohawk.riceball@gmail.com. All rights reserved.
//

#import "MixPlayerRecorder.h"

@implementation MixPlayerRecorder
@synthesize numInputFiles, isPlaying, frameNum, totalNumFrames, totalPlaybackTimeInSeconds, elapsedPlaybackTimeInSeconds, stoppedBecauseReachedEnd, isRecording;

void audioRouteChangeListenerCallback (
                                       void                      *inUserData,
                                       AudioSessionPropertyID    inPropertyID,
                                       UInt32                    inPropertyValueSize,
                                       const void                *inPropertyValue) 
{
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) return;
    
    MixPlayerRecorder *thePlayer = (MixPlayerRecorder*)inUserData;
    
    NSString *currentAudioRoute = [thePlayer getCurrentAudioRoute];
    
    NSRange speakerRange = [currentAudioRoute rangeOfString:@"Speaker"];
    if (speakerRange.location != NSNotFound)
    {
        NSLog(@"now is Speaker");
        [thePlayer setMicVolume:0];
    }
    
    NSRange headphoneRange = [currentAudioRoute rangeOfString:@"Headphone"];
    if (headphoneRange.location != NSNotFound)
    {
        NSLog(@"now is Headphone");
        [thePlayer setMicVolume:1];
    }
}


#pragma mark - audio callbacks and graph setup
static OSStatus micRenderCallback(void                          *inRefCon, 
                                  AudioUnitRenderActionFlags 	*ioActionFlags, 
                                  const AudioTimeStamp          *inTimeStamp, 
                                  UInt32 						inBusNumber, 
                                  UInt32 						inNumberFrames, 
                                  AudioBufferList               *ioData)
{
    MixPlayerRecorder *recorder = (MixPlayerRecorder*) inRefCon;
    OSStatus err = AudioUnitRender(recorder->rioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
	if (err) { printf("PerformThru: error %d\n", (int)err); return err; }
    
    return err;
}

static OSStatus audioFileCallback(void *inRefCon, 
                                 AudioUnitRenderActionFlags *ioActionFlags, 
                                 const AudioTimeStamp *inTimeStamp, 
                                 UInt32 inBusNumber, 
                                 UInt32 inNumberFrames, 
                                 AudioBufferList *ioData) 
{
    
    //printf("inBusNumber is %lu\n", inBusNumber);
    
    AudioFileRingBuffer *ringBuffer = (AudioFileRingBuffer *)inRefCon;
    
    AudioSampleType *out = (AudioSampleType *)ioData->mBuffers[0].mData;
    int samplesToCopy = ioData->mBuffers[0].mDataByteSize/sizeof(SInt16);
    //printf("audiocallback\n");
    SInt16 *buffer = [ringBuffer readFromRingBufferNumberOfSamples:samplesToCopy];
    //printf("helloworld\n");
    memcpy(out, buffer, samplesToCopy * sizeof(SInt16));
    out += samplesToCopy;
    
    return noErr;
    
}

// this render notification (called by the AUGraph) is used to keep track of the frame number position in the source audio
static OSStatus renderNotification(void *inRefCon, 
                                   AudioUnitRenderActionFlags *ioActionFlags, 
                                   const AudioTimeStamp *inTimeStamp, 
                                   UInt32 inBusNumber, 
                                   UInt32 inNumberFrames, 
                                   AudioBufferList *ioData)
{
    MixPlayerRecorder *player = (MixPlayerRecorder *)inRefCon;
    
    if (*ioActionFlags & kAudioUnitRenderAction_PostRender) {
        
        //printf("post render notification frameNum %ld inNumberFrames %ld\n", userData->frameNum, inNumberFrames);
        
        player.frameNum += inNumberFrames;
        
        [player postNotificationForElapsedTime];
        
        if (player.frameNum >= player.totalNumFrames) {
            //once done, stop the AUGraph and reset the lengths
            [player performSelectorOnMainThread:@selector(stop) withObject:nil waitUntilDone:NO];
            player.stoppedBecauseReachedEnd = YES;
            
        }
    }
    
    return noErr;
}

- (void)prepareAUGraph
{
    //create a new AUGraph
    error = NewAUGraph(&processingGraph);
    CheckError(error, "Cannot create AUGraph");
    
    //describe the output unit required (the RemoteIO)
    AudioComponentDescription rioDesc;
    rioDesc.componentType = kAudioUnitType_Output;
    rioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    rioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    rioDesc.componentFlags = 0;
    rioDesc.componentFlagsMask = 0;
    
    //describe the mixer unit
    AudioComponentDescription mixerDesc;
    mixerDesc.componentType = kAudioUnitType_Mixer;
    mixerDesc.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixerDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerDesc.componentFlags = 0;
    mixerDesc.componentFlagsMask = 0;
    
    //create two nodes for the graph
    AUNode rioNode;
    AUNode mixerNode;
    
    //put the audio units (from the descriptions) into the nodes and add them to the graph
    error = AUGraphAddNode(processingGraph, &rioDesc, &rioNode);
    CheckError(error, "Cannot add remote i/o node to the graph");
    
    error = AUGraphAddNode(processingGraph, &mixerDesc, &mixerNode);
    CheckError(error, "Cannot add mixer node to the graph");
    
    //open the AUGraph to access the audio units to configure them
    error = AUGraphOpen(processingGraph);
    CheckError(error, "Cannot open AUGraph");
    
    //obtain the remote i/o unit from the corresponding node
    error = AUGraphNodeInfo(processingGraph, rioNode, NULL, &rioUnit);
    CheckError(error, "Cannot obtain the remote i/o unit from the corresponding node");
    
    //enable input (mic recording) on the remote io unit
    UInt32 one = 1;
    error = AudioUnitSetProperty(rioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one));
    CheckError(error, "couldn't enable input on remote i/o unit");
    
    //create a render proc for the mic
    AURenderCallbackStruct inputProc;
    inputProc.inputProc = micRenderCallback;
    inputProc.inputProcRefCon = self;
    
    //set the render callback on the remote io unit
    error = AudioUnitSetProperty(rioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0, &inputProc, sizeof(inputProc));
    CheckError(error, "couldn't set render callback on remote i/o unit");
    
    AudioStreamBasicDescription micFormat;
    ASBDSetCanonical(&micFormat, 2, true);
    micFormat.mSampleRate = 44100;
    
    //apply the CAStreamBasicDescription to the remote i/o unit's input and output scope
    error = AudioUnitSetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &micFormat, sizeof(micFormat));
    CheckError(error, "couldn't set remote i/o unit's output client format");
    
    error = AudioUnitSetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &micFormat, sizeof(micFormat)); //1 or 0, this one?
    CheckError(error, "couldn't set remote i/o unit's input client format");
    
    
    
    
    
    //obtain the mixer unit from the corresponding node
    error = AUGraphNodeInfo(processingGraph, mixerNode, NULL, &mixerUnit);
    CheckError(error, "cannot obtain the mixer unit from the corresponding node");
    
    //start setting the mixer unit - find out how many file inputs are there by looking at the size of the soundbuffer
    UInt32 busCount = numInputFiles + 1;
    UInt32 micBus = numInputFiles;
    
    //set how many input buses the mixer unit has
    error = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &busCount, sizeof(busCount));
    CheckError(error, "cannot set number of input buses for mixer unit");
    
    //increase maximum frames per size (for some screen locking thingy)
    UInt32 maxFramesPerSlice = 4096;
    error = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, sizeof(maxFramesPerSlice));
    CheckError(error, "cannot set max frames per size");
    
    //set the stream format for the mic input to mixer
    error = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, micBus, &micFormat, sizeof(micFormat));
    CheckError(error, "cannot set mic format asbd on mixer input");
    
    for (int busNumber = 0; busNumber < micBus; busNumber++)
    {
        //now let's handle the audio file bus - set a render callback into mixer's input bus 1 - bus 0 will be handled later by the AUGraphConnectNodeInput
        AURenderCallbackStruct audioFileCallbackStruct;
        audioFileCallbackStruct.inputProc = &audioFileCallback;
        audioFileCallbackStruct.inputProcRefCon = [audioRingBuffers objectAtIndex:busNumber];
        
        error = AUGraphSetNodeInputCallback(processingGraph, mixerNode, busNumber, &audioFileCallbackStruct);
        CheckError(error, "Cannot set render callback for audio file on mixer input");
        
        //set the stream format for the audio file input bus (bus 0 of mixer input)
        error = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, busNumber, &micFormat, sizeof(micFormat));
        CheckError(error, "Cannot set stream format for audio file input bus of mixer unit");
    }
    
    error = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &micFormat, sizeof(micFormat));
    CheckError(error, "cannot set mixer output bus stream format");
    
    
    //now connect the nodes of the graph
    error = AUGraphConnectNodeInput(processingGraph, rioNode, 1, mixerNode, micBus);
    CheckError(error, "cannot connect remote io output node 1 to mixer input node 1");
    
    error = AUGraphConnectNodeInput(processingGraph, mixerNode, 0, rioNode, 0);
    CheckError(error, "cannot connect mixer output node 0 to remote io input node 0");
    
    error = AUGraphAddRenderNotify(processingGraph, renderNotification, self);
    CheckError(error, "cannot add AUGraphAddRenderNotify");
    
    //summary...
//    CAShow(processingGraph);
    
    //initalize the graph
    error = AUGraphInitialize(processingGraph);
    CheckError(error, "cannot initialize processing graph");
    
//    printf("Finished initializing graph\n");
}

#pragma mark - callable methods

- (MixPlayerRecorder *)initWithAudioFileURLs:(NSArray *)urls
{
    self = [super init];
    if (self) {
        
        //instantiate the ringbuffer array
        audioRingBuffers = [NSMutableArray arrayWithCapacity:urls.count];
        numInputFiles = urls.count;
        totalNumFrames = 0;
        
        //load the audio files into the ringbuffers
        [urls enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSURL *url = (NSURL *)obj;
            
            AudioFileRingBuffer *ringBuffer = [[AudioFileRingBuffer alloc] initWithAudioFile:url];
            [audioRingBuffers addObject:ringBuffer];
            
            if (ringBuffer.numFrames > totalNumFrames) totalNumFrames = ringBuffer.numFrames;
            
            //because when we put the ringBuffer into an array its retain count increases by 1.
            //we should call release now because we don't need it anymore in this block, let the array handle the next release.
            [ringBuffer release];
        }];
        
        //retain the audioRingBuffers, if not after one runloop it will be autoreleased then the AUGraph will choke and die
        [audioRingBuffers retain];
        [self prepareAUGraph];
        
        //set the stoppedBecauseReachedEnd flag to NO
        stoppedBecauseReachedEnd = NO;
        
        //record the total number of playable seconds (length of the mix) from the totalNumFrames which the prepareAUGraph function calculated for us
        totalPlaybackTimeInSeconds = totalNumFrames / 44100;
        //printf("totalNumFrames is %lu\n", totalNumFrames);
    }
    
    [[AVAudioSession sharedInstance] setDelegate: self];
    
    AudioSessionAddPropertyListener (
                                     kAudioSessionProperty_AudioRouteChange,
                                     audioRouteChangeListenerCallback,
                                     self);
    
    return self;
}

- (void)play
{
    error = AUGraphStart(processingGraph);
    CheckError(error, "Cannot start AUGraph");
    isPlaying = YES;
//    printf("AUGraph started\n");
    
    //post notifications
    [[NSNotificationCenter defaultCenter] postNotificationName:kMixPlayerRecorderPlaybackStarted object:self];
    
    //must do this because let's say if we were replaying again from the end, we need to tell the UI to "reset" the progress to 0 on start
    //if don't have this, we need to wait for the 1st second to update the UI
    [[NSNotificationCenter defaultCenter] postNotificationName:kMixPlayerRecorderPlaybackElapsedTimeAdvanced object:nil];

    
    NSString *currentAudioRoute = [self getCurrentAudioRoute];
    
    if ([currentAudioRoute isEqualToString:@"Speaker"])
    {
        [self setMicVolume:0];
    } else if ([currentAudioRoute isEqualToString:@"Headphone"])
    {
        [self setMicVolume:1];
    }
}

- (void)stop
{
    error = AUGraphStop(processingGraph);
    CheckError(error, "Cannot stop AUGraph");
    isPlaying = NO;
//    printf("AUGraph stopped\n");
    
    //post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:kMixPlayerRecorderPlaybackStopped object:self];
    
    if (isRecording)
    {
        //stop recording too
        [self stopRecording];
    }
    
    if (stoppedBecauseReachedEnd)
    {
        [audioRingBuffers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            AudioFileRingBuffer *buffer = (AudioFileRingBuffer *)obj;
            [buffer reset];
        }];
        
        frameNum = 0;
        elapsedPlaybackTimeInSeconds = 0;
        stoppedBecauseReachedEnd = NO;
    }
}

- (void)seekTo:(UInt32)targetSeconds
{
    [self stop];
    
    //convert seconds to frames
    UInt32 targetFrame = targetSeconds * 44100;
    
    //loop through every audio file ring buffer and change the read/seek position
    [audioRingBuffers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        AudioFileRingBuffer *buffer = (AudioFileRingBuffer *)obj;
        [buffer moveReadPositionOfAudioFileToFrame:targetFrame];
    }];
    
    //update the properties
    frameNum = targetFrame;
    elapsedPlaybackTimeInSeconds = targetSeconds;
    
    [self play];
}

- (void)setVolume:(AudioUnitParameterValue)vol forBus:(UInt32)busNumber
{
    error = AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, busNumber, vol, 0);
    CheckError(error, "Cannot change volume");
}

- (float)getVolumeForBus:(UInt32)busNumber
{
    float floatVolume;
    error = AudioUnitGetParameter(mixerUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, busNumber, &floatVolume);
    CheckError(error, "Cannot get volume value");
    
    return floatVolume;
}

- (BOOL)busNumberIsMuted:(int)busNumber
{
    float enabled;
    error = AudioUnitGetParameter(mixerUnit, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, busNumber, &enabled);
    
    return !(BOOL)enabled;
}

- (void)unmuteBusNumber:(int)busNumber
{
    float enabled = 1;
    error = AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, busNumber, enabled, 0);
}

- (void)muteBusNumber:(int)busNumber
{
    float enabled = 0;
    error = AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, busNumber, enabled, 0);
}

- (void)enableRecordingToFile:(NSURL *)filePath
{
    recorder = [[BoomzAUOutputCapturer alloc] initWithAudioUnit:rioUnit OutputURL:(CFURLRef)filePath AudioFileTypeID:kAudioFileCAFType forBusNumber:1];
    
    [recorder start];
    isRecording = YES;
    
    
    if ([[self getCurrentAudioRoute] isEqualToString:@"Speaker"])
    {
        [self setMicVolume:0];
    } else if ([[self getCurrentAudioRoute] isEqualToString:@"Headphones"])
    {
        [self setMicVolume:1];
    }
}

- (void)setMicVolume:(AudioUnitParameterValue)vol
{
    /*
     the numInputFiles ivar represents the total number of audio file inputs into the mixer unit.
     as the mic input callback is the last bus on the mixer unit, the bus number for the mic directly corresponds to the value of numInputFiles.
     
     for example, if numInputFiles is 3, mixer unit input bus 0,1,2 corresponds to audio file callbacks.
     bus 3 will then be the mic input callback, which == numInputFiles
     */
    
    [self setVolume:vol forBus:self.numInputFiles];
}

- (float)getMicVolume
{
    return [self getVolumeForBus:numInputFiles];
}

- (void)stopRecording
{
    [recorder stop];
    [recorder close];
    [recorder release];
    isRecording = NO;
}

-(bool)checkGraphStatus
{
    unsigned char result;
    AUGraphIsRunning(processingGraph, &result);
    return result;
}

#pragma mark - notification posting methods
-(void)postNotificationForElapsedTime
{
    //use frameNum and totalNumFrames for this, and we have 44100 samples (thus frames?) in one second of audio
    
    UInt32 tempElapsedTime = frameNum / 44100;
    if (tempElapsedTime != elapsedPlaybackTimeInSeconds) 
    {
        elapsedPlaybackTimeInSeconds = tempElapsedTime;
        
        //send notification
        [[NSNotificationCenter defaultCenter] postNotificationName:kMixPlayerRecorderPlaybackElapsedTimeAdvanced object:nil];
    }

}

- (void)dealloc
{
    //unobserve just just before this object is deallocated
    AudioSessionRemovePropertyListenerWithUserData(
                                            kAudioSessionProperty_AudioRouteChange,
                                            audioRouteChangeListenerCallback,
                                            self);
    
    [audioRingBuffers release];
    [super dealloc];
}

- (NSString*)getCurrentAudioRoute
{
    //possible returns: Headphones, Speaker or empty string
    
    CFDictionaryRef audioRoute;
    UInt32 propSize = sizeof(audioRoute);
    error = AudioSessionGetProperty(kAudioSessionProperty_AudioRouteDescription, &propSize, &audioRoute);
    CheckError(error, "Error getting audio session!");
    
    NSDictionary *audioRouteDict = (NSDictionary*)audioRoute;
    NSArray *outputsArray = [audioRouteDict objectForKey:@"RouteDetailedDescription_Outputs"];
    NSDictionary *outputsDict = [outputsArray objectAtIndex:0];
    NSString *hardware = [outputsDict objectForKey:@"RouteDetailedDescription_PortType"];
    
    return hardware;
}

@end
