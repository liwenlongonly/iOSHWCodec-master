//
//  AudioQueuePlayer.h
//  VHLivePlay
//
//  Created by liwenlong on 15/11/3.
//  Copyright © 2015年 vhall. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioQueuePlayer : NSObject

- (void)initAudio;

- (void)playPCMData:(unsigned char*)data withDataSize:(int)size;

- (void)stopPlayer;

- (void)clean;

@end
