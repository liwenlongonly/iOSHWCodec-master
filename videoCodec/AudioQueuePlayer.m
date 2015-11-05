//
//  AudioQueuePlayer.m
//  VHLivePlay
//
//  Created by liwenlong on 15/11/3.
//  Copyright © 2015年 vhall. All rights reserved.
//
#import "AudioQueuePlayer.h"
#import <AudioToolbox/AudioToolbox.h>

#define QUEUE_BUFFER_SIZE 3 //队列缓冲个数
#define MIN_SIZE_PER_FRAME 1024*2 //每侦最小数据长度

@interface AudioQueuePlayer()
{
    AudioQueueRef _audioQueue;//音频播放队列
    AudioQueueBufferRef _audioQueueBuffers[QUEUE_BUFFER_SIZE];//音频缓存
    NSLock * synlock ;///同步控制
}
@end

@implementation AudioQueuePlayer

#pragma mark - Private Method
/*
 试了下其实可以不用静态函数，但是c写法的函数内是无法调用[self ***]这种格式的写法，所以还是用静态函数通过void *input来获取原类指针
 这个回调存在的意义是为了重用缓冲buffer区，当通过AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);函数放入queue里面的音频文件播放完以后，通过这个函数通知
 调用者，这样可以重新再使用回调传回的AudioQueueBufferRef
 */
static void AudioPlayerAQInputCallback(void *input, AudioQueueRef outQ, AudioQueueBufferRef outQB)
{
     VHLog(@"outQB:%d", (unsigned int)outQB->mAudioDataByteSize);
    outQB->mAudioDataByteSize = 0;
    AudioQueuePlayer *mainviewcontroller = (__bridge AudioQueuePlayer *)input;
}

-(void)initAudio
{
    ///设置音频参数
    AudioStreamBasicDescription audioDescription;///音频参数
    audioDescription.mSampleRate = 16000;//采样率
    audioDescription.mFormatID = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioDescription.mChannelsPerFrame = 1;///单声道
    audioDescription.mFramesPerPacket = 1;//每一个packet一侦数据
    audioDescription.mBitsPerChannel = 16;//每个采样点16bit量化
    audioDescription.mBytesPerFrame = (audioDescription.mBitsPerChannel/8) * audioDescription.mChannelsPerFrame;
    audioDescription.mBytesPerPacket = audioDescription.mBytesPerFrame ;
    ///创建一个新的从audioqueue到硬件层的通道
    //	AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &audioQueue);///使用当前线程播
    AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, (__bridge void * _Nullable)(self), nil, nil, 0, &_audioQueue);//使用player的内部线程播
    ////添加buffer区
    for(int i=0;i<QUEUE_BUFFER_SIZE;i++)
    {
        int result =  AudioQueueAllocateBuffer(_audioQueue, MIN_SIZE_PER_FRAME, &_audioQueueBuffers[i]);///创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
        VHLog(@"AudioQueueAllocateBuffer i = %d,result = %d",i,result);
    }
    AudioQueueStart(_audioQueue, NULL);
}

#pragma mark - Public Method
- (void)playPCMData:(unsigned char*)data withDataSize:(int)size
{
    for (int i=0; i<QUEUE_BUFFER_SIZE; i++) {
        VHLog(@"index:%d size:%d",i,(unsigned int)_audioQueueBuffers[i]->mAudioDataByteSize);
        if (_audioQueueBuffers[i]->mAudioDataByteSize<=0) {
            _audioQueueBuffers[i]->mAudioDataByteSize =size;
            memcpy(_audioQueueBuffers[i]->mAudioData, data, size);
            OSStatus status = AudioQueueEnqueueBuffer(_audioQueue, _audioQueueBuffers[i], 0, NULL);
            break;
        }
    }
}

- (void)stopPlayer
{
    AudioQueueStop(_audioQueue,TRUE);
}

-(void)clean
{
    AudioQueueDispose(_audioQueue,YES);
}

#pragma mark - Lifecycle Method

- (instancetype)init
{
    self = [super init];
    if (self) {
        synlock = [[NSLock alloc] init];
    }
    return self;
}

@end
