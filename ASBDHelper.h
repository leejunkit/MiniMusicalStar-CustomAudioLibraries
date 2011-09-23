//
//  ASBDHelper.h
//  ThirdAttempt
//
//  Created by Jun Kit on 7/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudioTypes.h>
#include <CoreFoundation/CoreFoundation.h>

//	This is a macro that does a sizeof and casts the result to a UInt32. This is useful for all the
//	places where -wshorten64-32 catches assigning a sizeof expression to a UInt32.
//	For want of a better place to park this, we'll park it here.
#define	SizeOf32(X)	((UInt32)sizeof(X))

//	This is a macro that does a offsetof and casts the result to a UInt32. This is useful for all the
//	places where -wshorten64-32 catches assigning an offsetof expression to a UInt32.
//	For want of a better place to park this, we'll park it here.
#define	OffsetOf32(X, Y)	((UInt32)offsetof(X, Y))

//	This macro casts the expression to a UInt32. It is called out specially to allow us to track casts
//	that have been added purely to avert -wshorten64-32 warnings on 64 bit platforms.
//	For want of a better place to park this, we'll park it here.
#define	ToUInt32(X)	((UInt32)(X))

// define Leopard specific symbols for backward compatibility if applicable
#if COREAUDIOTYPES_VERSION < 1050
typedef Float32 AudioSampleType;
enum { kAudioFormatFlagsCanonical = kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked };
#endif
#if COREAUDIOTYPES_VERSION < 1051
typedef Float32 AudioUnitSampleType;
enum {
	kLinearPCMFormatFlagsSampleFractionShift    = 7,
	kLinearPCMFormatFlagsSampleFractionMask     = (0x3F << kLinearPCMFormatFlagsSampleFractionShift),
};
#endif

//	define the IsMixable format flag for all versions of the system
#if (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_3)
enum { kIsNonMixableFlag = kAudioFormatFlagIsNonMixable };
#else
enum { kIsNonMixableFlag = (1L << 6) };
#endif

void ASBDSetAUCanonical(AudioStreamBasicDescription* asbd, UInt32 nChannels, bool interleaved);
void ASBDSetCanonical(AudioStreamBasicDescription* asbd, UInt32 nChannels, bool interleaved);
void ASBDSetM4A(AudioStreamBasicDescription* asbd, UInt32 nChannels);
void ASBDSetIMA4(AudioStreamBasicDescription* asbd, UInt32 nChannels);
void ASBDPrint(AudioStreamBasicDescription* asbd);