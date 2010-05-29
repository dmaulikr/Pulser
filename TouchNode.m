//
//  TouchNode.m
//  Pulser
//
//  Created by Matthew Mcgoogan on 4/11/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "TouchNode.h"
#import "GameLayer.h"
#import "MeteorNode.h"
#import "Constants.h"


#pragma mark -
#pragma mark Chipmunk

static void
dampingVelocityFunc(cpBody *body, cpVect gravity, cpFloat damping, cpFloat dt)
{
	damping = 0.9;
	cpBodyUpdateVelocity(body, gravity, damping, dt);
}

#pragma mark -



@interface TouchNode (PrivateMethods)

- (CGPoint)localTouchPoint:(UITouch *)touch;

@end

@implementation TouchNode

@synthesize sprite, particleSystem, player, shape;

+ (id)nodeWithPosition:(CGPoint)pos sheet:(CCSpriteSheet *)sheet space:(cpSpace *)space {
	return [[[self alloc] initWithSpritePosition:pos sheet:(CCSpriteSheet *)sheet space:space] autorelease];
}

- (id) init {
	if ((self = [super init])) {
		sprite = nil;
		springBody = NULL;
		springJoint = NULL;
		player = nil;
	}
	
	return self;
}

- (id)initWithSpritePosition:(CGPoint)pos sheet:(CCSpriteSheet *)sheet space:(cpSpace *)space {
	if ((self = [self init])) {
		
		_space = space;
		
		cpBody *body = cpBodyNew(TOUCHNODE_MASS, cpMomentForCircle(TOUCHNODE_MASS, TOUCHNODE_RADIUS, TOUCHNODE_RADIUS, cpvzero));
		body->velocity_func = dampingVelocityFunc;
		body->p = pos;
		
		shape = cpCircleShapeNew(body, TOUCHNODE_RADIUS, cpvzero);
		shape->u = 0.2;
		shape->e = 0.2;
		shape->collision_type = TOUCHNODE_COL_GROUP;
		shape->data = self;
		
		cpSpaceAddBody(space, body);
		cpSpaceAddShape(space, shape);
		
		[self initSpriteWithPosition:pos sheet:sheet];
	}
	
	return self;
}

- (void)initSpriteWithPosition:(CGPoint)pos sheet:(CCSpriteSheet *)sheet {
	if (!sprite) {
		/*
		particleSystem = [[CCParticleSun alloc] initWithTotalParticles:10];
		particleSystem.position = pos;
		particleSystem.posVar = CGPointMake(50.0,50.0);
		particleSystem.startColor = ccc4FFromccc4B(ccc4(66, 103, 223, 255));
		[self addChild:particleSystem];
		 */
		
		sprite = [[CCSprite alloc] initWithSpriteSheet:sheet rect:CGRectMake(0.0, 0.0, 144.0, 144.0)];
		sprite.scaleX = 0.01;
		sprite.scaleY = 0.01;
		[sheet addChild:sprite];
		sprite.position = pos;
		
		id s1,s2,s3,s4,s5;
		s1 = [CCScaleTo actionWithDuration:1.0f scale:1.1];
		s2 = [CCScaleTo actionWithDuration:0.2f scale:1.0];
		[sprite runAction:[CCSequence actions:s1, s2, nil]];
	}
}

- (void)onEnter {
	[super onEnter];
	[[CCTouchDispatcher sharedDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:YES];
}

- (void)onExit {
	[super onExit];
	[[CCTouchDispatcher sharedDispatcher] removeDelegate:self];
}

#pragma mark -
#pragma mark Coloring

- (void)tintNode:(UIColor *)color {
	if (sprite) {
		int num;
		
		CGColorRef cgColor = [color CGColor];
		
		num = CGColorGetNumberOfComponents(cgColor);
		CGFloat *colorComponents;
		CGFloat newComps[num];
		colorComponents = CGColorGetComponents(cgColor);
		
		for (int i=0 ; i<num ; i++) {
			newComps[i] = colorComponents[i] * 255.0;
		}
		
		id<CCRGBAProtocol> tn = (id<CCRGBAProtocol>)sprite;
		[tn setColor:ccc3((GLubyte)newComps[0], (GLubyte)newComps[1], (GLubyte)newComps[2])];
	}
}

#define PROXIMITY_THRESHOLD 400.0f
#define DEFAULT_COLOR ccc3(66,103,223)

- (void)tintNodeBasedOnMeteorProximity:(NSArray *)meteors {
	id<CCRGBAProtocol> tn = (id<CCRGBAProtocol>)sprite;
	ccColor3B color = [tn color];
	
	MeteorNode *closest = nil;
	for (MeteorNode *node in meteors) {
		if (closest == nil) {
			closest = node;
			continue;
		}
		else if (fabsf(ccpDistance(node.particleSystem.position, sprite.position)) < fabsf(ccpDistance(closest.particleSystem.position, sprite.position))) {
			closest = node;
			continue;
		}
	}
	
	CGFloat distance = fabsf(ccpDistance(closest.particleSystem.position, sprite.position));
	
	if (distance > PROXIMITY_THRESHOLD) {
		[tn setColor:DEFAULT_COLOR];
		return;
	}
	
	CGFloat range = (PROXIMITY_THRESHOLD - 60.0);
	CGFloat normDist = distance - 60.0;
	normDist = normDist <= 0.0 ? 1.0 : normDist;
	
	CGFloat colorFactor = (range - normDist) / range;
	/*
	 *	We want a tendency toward red, red tones will increase with proximity,
	 *	green & blue will decrease
	 */
	color.r = (int)(255.0 * colorFactor);
	color.g = 103 - (int)(103.0*colorFactor);
	color.b = 223 - (int)(223.0*colorFactor);
	
	[tn setColor:color];
}

#pragma mark -
#pragma mark Chipmunk

- (void)setPosition:(CGPoint)pos {
	[self.sprite setPosition:pos];
}

- (void)setRotation:(float)rot {
	[self.sprite setRotation:rot];
}

- (void)prepForRemoval {
	if (springBody != NULL) {
		cpSpaceRemoveBody(_space, springBody);
		cpBodyFree(springBody);
		springBody = NULL;
	}
	
	if (springJoint != NULL) {
		cpSpaceRemoveConstraint(_space, springJoint);
		cpConstraintFree(springJoint);
		springJoint = NULL;
	}
}

#pragma mark -
#pragma mark Touch Handler

- (CGPoint)localTouchPoint:(UITouch *)touch {
	return [[CCDirector sharedDirector] convertToGL:[touch locationInView:touch.view]];
}

- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
	BOOL shouldCatch = NO;
	CGPoint pos = [self localTouchPoint:touch];
	
	CGFloat delta = fabsf(ccpDistance(pos, sprite.position));
	
	if (delta < TOUCHNODE_RADIUS) {
		if (springBody == NULL) {
			springBody = cpBodyNew(INFINITY, INFINITY);
			springBody->p = pos;
			
			springJoint = cpSlideJointNew(springBody, shape->body, cpvzero, cpvzero, 0.0, 10.0);
			cpSpaceAddConstraint(_space, springJoint);
			
			shouldCatch = YES;
		}
	}
	
	return shouldCatch;
}

- (void)ccTouchMoved:(UITouch *)touch withEvent:(UIEvent *)event {
	CGPoint pos = [self localTouchPoint:touch];
	
	springBody->p = pos;
}

- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
	/*
	CGPoint seedStart = [[CCDirector sharedDirector] convertToGL:[touch previousLocationInView:touch.view]];
	CGPoint seedEnd = [self localTouchPoint:touch];
	
	CGPoint delta = ccpSub(seedEnd, seedStart);
	delta = ccpMult(delta, 500.0);
	cpBodyApplyImpulse(shape->body, delta, cpvzero);
	 */
	
	CGPoint p1 = shape->body->p;
	CGPoint p2 = springBody->p;
	
	CGPoint vMag = ccpSub(p2, p1);
	vMag = ccpNormalize(vMag);
	vMag = ccpMult(vMag, 1000.0);
	
	cpSpaceRemoveConstraint(_space, springJoint);
	cpConstraintFree(springJoint);
	springJoint = NULL;
	
	cpSpaceRemoveBody(_space, springBody);
	cpBodyFree(springBody);
	springBody = NULL;
	
	cpBodyApplyImpulse(shape->body, vMag, cpvzero);
}

@end