//
//  PlaceMark.h
//  map
//
//  Created by Ruben on 1/7/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>


@interface PlaceMark : NSObject <MKAnnotation> {
	CLLocationCoordinate2D coordinate;
	NSString* strTitle;
	NSString* strSubTitle;
}

@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property int clusterId;
@property float probability;

- (id)initWithCoordinate:(CLLocationCoordinate2D) coordinate 
				   title:(NSString*) sTitle 
				subtitle:(NSString*) sSubTitle;
- (id)initWithLongitude:(CLLocationDegrees) longitude
			   latitude:(CLLocationDegrees) latitude
				   title:(NSString*) sTitle 
				subtitle:(NSString*) sSubTitle;
- (NSString *)subtitle;
- (NSString *)title;
- (CLLocationCoordinate2D)getCoordinate;

@end