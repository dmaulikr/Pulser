//
//  PulseNode.h
//  Pulser
//
//  Created by Matthew Mcgoogan on 4/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"
#import "chipmunk.h"
@class MeteorNode;

#define PULSENODE_RADIUS 50.0f
#define PULSENODE_MASS 50.0f

@interface PulseNode : CCLayer {
	CCParticleSystem *particleSystem;
	cpShape *shape;
	NSMutableArray *meteors;
	
	@private
	cpSpace *_space;
	CGPoint currentDestination;
	cpBody *pathBody;
}

@property (nonatomic, retain) CCParticleSystem *particleSystem;
@property (nonatomic, readonly) NSMutableArray *meteors;

- (id)initWithPosition:(CGPoint)pos space:(cpSpace *)space;

- (CGPoint)randomPoint;

- (void)removeMeteor:(MeteorNode *)meteor;

@end