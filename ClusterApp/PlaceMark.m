//
//  PlaceMark.m
//  map
//
//  Created by Ruben on 1/7/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PlaceMark.h"


@implementation PlaceMark

@synthesize coordinate;
@synthesize clusterId;
@synthesize probability;

- (NSString *)subtitle{
	return strTitle;
}
- (NSString *)title{
	return strSubTitle;
}

- (CLLocationCoordinate2D)getCoordinate
{
	return coordinate;
}

-(id)initWithCoordinate:(CLLocationCoordinate2D) c   
				  title:(NSString*) t 
			   subtitle:(NSString*) st {
	coordinate=c;
	strTitle=t;
	strSubTitle=st;
	[strTitle retain];
	[strSubTitle retain];
	return self;
}

- (id)initWithLongitude:(CLLocationDegrees) longitude
			   latitude:(CLLocationDegrees) latitude
				  title:(NSString*) sTitle 
			   subtitle:(NSString*) sSubTitle {
	CLLocationCoordinate2D location;
	location.longitude = longitude;
	location.latitude = latitude;
	return [self initWithCoordinate:location
							  title:sTitle 
						   subtitle:sSubTitle];
}

-(void)dealloc
{
    [strTitle release];
    [strSubTitle release];
    
    [super dealloc];
}

@end
