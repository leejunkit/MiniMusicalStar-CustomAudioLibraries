//
//  MixPlayerRecorder.h
//  Mini Musical Star
//
//  Created by Jun Kit Lee on 11/8/11.
//  Copyright 2011 mohawk.riceball@gmail.com. All rights reserved.
//

/*
    To use, init with an NSArray of audio file URLs. Then you can simply call play to play all the files simultaneously.
    To record, just call enableRecordingToFile right after you init and before you play.
 */

//this class will post notifications when events occur. Register with NSNotificationCenter to receive them.
#define kMixPlayerRecorderPlaybackStarted @"kMixPlayerRecorderPlaybackStarted"
#define kMixPlayerRecorderPlaybackStopped @"kMixPlayerRecorderPlaybackStopped"
#define kMixPlayerRecorderPlaybackElapsedTimeAdvanced @"kMixPlayerRecorderPlaybackElapsedTimeAdvanced"
#define kMixPlayerRecorderRecordingHasReachedEnd @"kMixPlayerRecorderRecordingHasReachedEnd"
#define kMixPlayerRecorderPlayingHasReachedEnd @"kMixPlayerRecorderPlayingHasReachedEnd"
#define kMixPlayerRecorderAudioRouteHasChanged @"kMixPlayerRecorderAudioRouteHasChanged"

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "ASBDHelper.h"
#import "CAErrorHandling.h"
#import "AudioFileRingBuffer.h"
#import "BoomzAUOutputCapturer.h"

@interface MixPlayerRecorder : NSObject {
    NSMutableArray *audioRingBuffers;
    int numInputFiles;
    
    //AUGraph objects
    OSStatus error;
    AUGraph processingGraph;
    AudioUnit rioUnit;
    AudioUnit mixerUnit;
    AudioStreamBasicDescription asbdOutputFormat;
    
    //recording facilities
    bool isRecording;
    BoomzAUOutputCapturer *recorder;
    
    //playback state flags
    UInt32 frameNum; //current playback position of the mix in frames
    UInt32 totalNumFrames; //total length in frames of the mix
    bool stoppedBecauseReachedEnd;
    
    //to send elasped time notifications
    UInt32 totalPlaybackTimeInSeconds;
    UInt32 elapsedPlaybackTimeInSeconds;
    bool isPlaying;
}

@property (nonatomic, readonly) int numInputFiles;
@property (nonatomic, readonly) bool isPlaying;
@property (nonatomic) bool stoppedBecauseReachedEnd;
@property (nonatomic) UInt32 frameNum;
@property (nonatomic, readonly) UInt32 totalNumFrames;
@property (nonatomic, readonly) UInt32 totalPlaybackTimeInSeconds; //read this to find out the total length of the mix
@property (nonatomic, readonly) UInt32 elapsedPlaybackTimeInSeconds; //read this when you are notified with kMixPlayerRecorderPlaybackElapsedTimeAdvanced to find out the new elapsed time (usually in periods of 1 second each)
@property (nonatomic, readonly) bool isRecording; //read this to find out if the graph is recording the mic

-(MixPlayerRecorder *)initWithAudioFileURLs: (NSArray *)urls;
-(void)play;
-(void)stop;
-(void)seekTo:(UInt32)targetSeconds;
-(void)setVolume:(AudioUnitParameterValue)vol forBus:(UInt32)busNumber;
-(float)getVolumeForBus:(UInt32)busNumber;

-(BOOL)busNumberIsMuted:(int)busNumber;
-(void)unmuteBusNumber:(int)busNumber;
-(void)muteBusNumber:(int)busNumber;

//calling this enables recording for the next time you play the graph for ONE TIME ONLY
//For example, if you call play, then stop, then play again, it will only record the time between the first play-to-stop
//Every time you want to record something you have to call this method and specify a filepath url.
-(void)enableRecordingToFile: (NSURL *)filePath;
-(void)setMicVolume: (float)vol;
-(float)getMicVolume;

//this is automatically called when you stop the graph if isRecording is YES, otherwise you can manually call this to stop recording
-(void)stopRecording;

-(void)postNotificationForElapsedTime; //you don't have to call this manually
-(bool)checkGraphStatus; //for testing purposes only

- (NSString*)getCurrentAudioRoute;
- (NSString*)checkHardwareAndAdjustVolume;
- (void)postNotificationForAudioRouteChange;
@end
