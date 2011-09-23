//
//  ASBDHelper.c
//  ThirdAttempt
//
//  Created by Jun Kit on 7/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include "ASBDHelper.h"

//this one apparently produces the best PCM (suitable for speaker output)
void ASBDSetCanonical(AudioStreamBasicDescription* asbd, UInt32 nChannels, bool interleaved)
{
    //memset(&asbd, 0, sizeof(asbd));
    asbd->mFormatID = kAudioFormatLinearPCM;
    int sampleSize = SizeOf32(AudioSampleType);
    asbd->mFormatFlags = kAudioFormatFlagsCanonical;
    asbd->mBitsPerChannel = 8 * sampleSize;
    asbd->mChannelsPerFrame = nChannels;
    asbd->mFramesPerPacket = 1;
    if (interleaved)
        asbd->mBytesPerPacket = asbd->mBytesPerFrame = nChannels * sampleSize;
    else {
        asbd->mBytesPerPacket = asbd->mBytesPerFrame = sampleSize;
        asbd->mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
    }
}

//this one is when you wanna write out to m4a (AAC) PLEASE DON'T USE THIS FOR READING
//if you wanna read go and use ExtAudioFileGetProperty and get kExtAudioFileProperty_FileDataFormat
void ASBDSetM4A(AudioStreamBasicDescription* asbd, UInt32 nChannels)
{
    //memset(&asbd, 0, sizeof(asbd));
    asbd->mSampleRate = 44100.00;
    asbd->mFormatID = kAudioFormatMPEG4AAC;
    asbd->mFormatFlags = kMPEG4Object_AAC_Main;
    asbd->mFramesPerPacket = 1024;
    asbd->mChannelsPerFrame = nChannels;
    asbd->mBitsPerChannel = 0;
    asbd->mBytesPerPacket = 0;
    asbd->mBytesPerFrame = 0;
    asbd->mReserved = 0;
}

void ASBDSetIMA4(AudioStreamBasicDescription* asbd, UInt32 nChannels)
{
    asbd->mSampleRate = 44100; 
    asbd->mFormatID = kAudioFormatAppleIMA4; 
    asbd->mFormatFlags = 0; 
    asbd->mBytesPerPacket = 0; 
    asbd->mFramesPerPacket = 0; 
    asbd->mBytesPerFrame = 0; 
    asbd->mChannelsPerFrame = 2; 
    asbd->mBitsPerChannel = 0;
}

void ASBDPrint(AudioStreamBasicDescription* asbd)
{
    
}