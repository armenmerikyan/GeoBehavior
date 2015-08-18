//
//  ViewController.h
//  ClusterApp
//
//  Created by Tatevik Gasparyan on 4/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#include "svm.h"

#include "KMlocal.h"

#define POINTS_DICTIONARY @"pointsDictionary"
#define COUNT_DICTIONARY @"countsDictionary"
#define dim 2
#define maxPts 10000000
//#define clustersCount 4
@class MyCLController;
@class SQLiteManager;

@interface ViewController : UIViewController<MKMapViewDelegate>
{
    MyCLController* locationManager;
    //NSMutableDictionary* pointsDictionary;
    //NSMutableDictionary* countDictionary;
    //NSMutableDictionary* probabilityDictionary;
    
    IBOutlet UILabel *sampleCount;
    IBOutlet UILabel *locationsCount;
    IBOutlet UILabel *clusterCount;    
    IBOutlet UILabel *distinctCount;    
    NSMutableArray* centerPoints;
    NSMutableArray* allClustersCentersArray;
    NSDictionary* visitCentersCountArray;
    MKMapView* map;
    int pointsCount;
    int nPts;     
    int updateCount;                                 // actual number of points
    int clustersCount;
    IBOutlet UISlider *slider;
    SQLiteManager* sqliteManager;
    KMfilterCenters* ctrs;
    KMdata *dataPts;
    NSArray* uniqieCenters;
    NSUInteger selectedPin;
    int lastTouchedPin;
    int changedClusterId;
    BOOL useCurrentLocationAsStartCluster;
    BOOL isShowingDetail;
    BOOL isQueryAll;
    CGPoint selectedPoint;
    CGPoint defaultPoint;
    UIButton* calculateButton;
    UIButton* allButton;
    UIButton* historyButton;
    NSMutableArray* arrayOfLines;
}

@property(nonatomic, retain) IBOutlet UIButton* allButton;
@property(nonatomic, retain) IBOutlet UIButton* calculateButton;
@property(nonatomic, retain) IBOutlet UIButton* historyButton;
@property (nonatomic, retain) UILabel *avgDist;
@property (nonatomic, retain) UILabel *clusterCount;
@property (nonatomic, retain) UILabel *sampleCount;
@property (nonatomic, retain) UILabel *locationsCount;
@property (nonatomic, retain) UILabel *distinctCount;
@property(nonatomic, retain) IBOutlet UISegmentedControl* algorithm;
@property(nonatomic, retain) IBOutlet MKMapView* map;
@property(nonatomic, retain) IBOutlet UISlider* slider;
-(IBAction) sliderChanged:(id)sender;
-(IBAction) drawClusters:(id)sender;
-(IBAction) setInputs:(KMdata&)data;
-(IBAction) drawCenters:(KMfilterCenters&)centers;
-(IBAction)createLocationTable;
-(IBAction) drawLayers:(id)sender;
-(IBAction) drawLayersAll:(id)sender;
-(IBAction) drawDistinctLocations:(id)sender;
-(NSArray*) getUniqueCenters:(KMfilterCenters)centers;
-(NSArray*) getAllCentersArrayFromLocations;
-(IBAction) getProbabilities:(CGPoint)centerPoint :(NSMutableDictionary*)locationsProbability;
-(IBAction)changeCurrentCluster;
-(BOOL)comparePoints:(CGPoint)p1 :(CGPoint)p2;
-(IBAction)calculateProbabilities:(CGPoint)centerPoint :(NSMutableDictionary*)locationsProbability;
-(UIImage*) getImageWithLabel:(int)digit imageNamed:(NSString*)name;
-(IBAction)drawLine:(CGPoint)points1 :(CGPoint)points2;
-(IBAction)removeAllLines;

-(IBAction)runAlgorithm;

@end
